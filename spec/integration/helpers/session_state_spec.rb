# frozen_string_literal: true

require 'erb'
require 'json'
require 'timeout'
require 'selenium-webdriver'
require 'time'
require 'tmpdir'
require 'yaml'

module SessionStateSpec
  TEMPLATE = File.expand_path('../../../lib/generators/templates/helpers/session_state.tt', __dir__)

  # Renders the template and loads it from a temp file that is removed straight away.
  def self.load_template
    Dir.mktmpdir('session_state_tt') do |dir|
      file = File.join(dir, 'session_state.rb')
      File.write(file, ERB.new(File.read(TEMPLATE), trim_mode: '-').result)
      load file
    end
  end
end
SessionStateSpec.load_template

module SessionStateSpec
  # Implements exactly the driver calls SessionState uses and records them in order.
  class FakeDriver
    ORIGIN_URL = 'https://raider-test-site.onrender.com/account'

    def initialize(cookies: [], local: {}, session: {}, reject: nil, url: ORIGIN_URL)
      @reject = reject
      @page = { cookies:, url: }
      @storage = { 'localStorage' => local, 'sessionStorage' => session }
      @log = { calls: [], added: [] }
    end

    def calls = @log[:calls]
    def added = @log[:added]
    def local = @storage['localStorage']
    def session = @storage['sessionStorage']

    def manage = self
    def navigate = self
    def all_cookies = @page[:cookies]
    def current_url = @page[:url]
    def refresh = calls << :refresh
    def delete_all_cookies = calls << :delete_all_cookies

    def add_cookie(cookie)
      raise 'rejected' if @reject&.call(cookie)

      calls << :add_cookie
      added << cookie
    end

    def to(url)
      @page[:url] = url
      calls << [:to, url]
    end

    def execute_script(_script, *args)
      kind, values = args
      return @storage[kind] if values.nil?

      calls << [:write, kind]
      @storage[kind] = values
    end
  end

  # The browser end of a real Selenium::WebDriver::Manager: records the wire payloads it receives.
  class FakeBridge
    def initialize(log, reject)
      @log = log
      @reject = reject
    end

    def add_cookie(cookie)
      raise Selenium::WebDriver::Error::InvalidArgumentError, 'rejected' if @reject&.call(cookie)

      @log[:calls] << :add_cookie
      @log[:added] << cookie
    end

    def delete_all_cookies = @log[:calls] << :delete_all_cookies
    def cookies = []
  end

  # A FakeDriver whose manage is the real Selenium Manager, so its key translation is under test.
  class ManagedDriver < FakeDriver
    def manage
      @manage ||= Selenium::WebDriver::Manager.new(FakeBridge.new(@log, @reject))
    end
  end
end

describe 'SessionState' do
  let(:url) { 'https://raider-test-site.onrender.com/' }
  let(:driver) { SessionStateSpec::FakeDriver.new(cookies:, local: { 'token' => 'abc' }, session: { 'tab' => '1' }) }
  let(:state) { SessionState.new(driver) }
  let(:config) { { 'url' => url } }

  def origin = 'https://raider-test-site.onrender.com'
  def state_file = File.join('.raider', 'auth', 'user.json')

  def cookies
    [{ name: 'sid', value: 's3cr3t', domain: 'raider-test-site.onrender.com', path: '/', expires: nil,
       secure: true, http_only: true, same_site: 'Lax' }]
  end

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p('config')
        example.run
      end
    end
  end

  before do
    File.write('config/config.yml', YAML.dump(config))
    stub_const('ENV', ENV.to_h.merge('RAIDER_LOGIN_STATE' => nil))
  end

  def write_state(overrides = {})
    FileUtils.mkdir_p(File.dirname(state_file))
    data = { 'format' => 1, 'name' => 'user', 'origin' => origin, 'saved_at' => (Time.now.utc - 10).iso8601,
             'cookies' => [], 'local_storage' => {}, 'session_storage' => {} }.merge(overrides)
    File.write(state_file, JSON.generate(data))
  end

  def saved
    JSON.parse(File.read(state_file))
  end

  def saved_cookie(name, **attrs)
    { 'name' => name, 'value' => 'v', 'domain' => 'raider-test-site.onrender.com', 'path' => '/',
      'expires' => nil, 'secure' => false, 'http_only' => false, 'same_site' => nil }.merge(attrs.transform_keys(&:to_s))
  end

  it 'rejects a name outside [a-z0-9_-]' do
    expect { SessionState.new(driver, name: '../x') }.to raise_error(ArgumentError)
    expect { SessionState.new(driver, name: 'Admin') }.to raise_error(ArgumentError)
  end

  it 'saves format 1 with origin, saved_at, cookies and both storages' do
    state.save
    expect(saved).to include('format' => 1, 'name' => 'user', 'origin' => origin,
                             'local_storage' => { 'token' => 'abc' }, 'session_storage' => { 'tab' => '1' })
    expect { Time.iso8601(saved['saved_at']) }.not_to raise_error
    expect(saved['cookies'].first).to include('name' => 'sid', 'http_only' => true, 'secure' => true)
  end

  it 'writes the file 0600 in a 0700 directory, atomically' do
    state.save
    expect(File.stat(state_file).mode & 0o777).to eq(0o600)
    expect(File.stat(File.dirname(state_file)).mode & 0o777).to eq(0o700)
    expect(Dir.glob('.raider/auth/*.tmp')).to be_empty
  end

  context 'with a url that has a port and a path' do
    let(:url) { 'https://x.test:8443/app/' }

    it 'derives the origin without path or trailing slash' do
      state.save
      expect(saved['origin']).to eq('https://x.test:8443')
    end
  end

  describe '#save on another origin' do
    it 'goes back to the origin before reading when the login ended elsewhere' do
      sso = SessionStateSpec::FakeDriver.new(url: 'https://sso.other.test/x')
      SessionState.new(sso).save
      expect(sso.calls).to eq([[:to, "#{origin}/"]])
    end

    it 'stays put when the login ended on the origin' do
      state.save
      expect(driver.calls).to be_empty
    end
  end

  describe '#fresh?' do
    it 'is false when the file is missing' do
      expect(state.fresh?).to be(false)
    end

    it 'is true for a recent file of the same format and origin' do
      write_state
      expect(state.fresh?).to be(true)
    end

    it 'is false for another format, another origin or an old file' do
      write_state('format' => 2)
      expect(state.fresh?).to be(false)
      write_state('origin' => 'https://other.test')
      expect(state.fresh?).to be(false)
      write_state('saved_at' => (Time.now.utc - 3601).iso8601)
      expect(state.fresh?).to be(false)
    end

    context 'with login_state max_age 30' do
      let(:config) { { 'url' => url, 'login_state' => { 'max_age' => 30 } } }

      it 'is false for a file older than max_age' do
        write_state('saved_at' => (Time.now.utc - 59).iso8601)
        expect(state.fresh?).to be(false)
      end
    end
  end

  describe '#restore' do
    let(:driver) { SessionStateSpec::ManagedDriver.new }

    it 'restores live cookies for the origin and skips expired and foreign ones' do
      write_state('cookies' => [
                    saved_cookie('session'),
                    saved_cookie('future', expires: (Time.now.utc + 86_400).iso8601),
                    saved_cookie('past', expires: (Time.now.utc - 1).iso8601),
                    saved_cookie('dotted', domain: '.raider-test-site.onrender.com'),
                    saved_cookie('foreign', domain: 'other.com')
                  ], 'local_storage' => { 'a' => 'b' })
      warning = "[login_state] 2 cookies skipped (expired or another domain) from #{state_file}\n"
      expect { expect(state.restore).to be(true) }.to output(warning).to_stderr
      expect(driver.added.map { |c| c[:name] }).to eq(%w[session future dotted])
      expect(driver.calls).to eq([[:to, "#{origin}/"], :delete_all_cookies, :add_cookie, :add_cookie, :add_cookie,
                                  [:write, 'localStorage'], [:write, 'sessionStorage'], :refresh])
    end

    it 'hands Selenium the cookie keys it translates to the wire format' do
      write_state('cookies' => [saved_cookie('session', same_site: 'Lax', http_only: true),
                                saved_cookie('future', expires: (Time.now.utc + 86_400).iso8601)])
      expect(state.restore).to be(true)
      expect(driver.added.first).to include(sameSite: 'Lax', httpOnly: true, secure: false)
      expect(driver.added.flat_map(&:keys)).not_to include(:same_site, :http_only, :expires)
      expect(driver.added.last[:expiry]).to be_a(Integer)
    end

    it 'returns false and warns for corrupt JSON' do
      FileUtils.mkdir_p(File.dirname(state_file))
      File.write(state_file, '{"format":')
      expect { expect(state.restore).to be(false) }.to output(/\[login_state\].*user\.json/).to_stderr
    end
  end

  it 'never prints cookie or storage values' do
    leak = /s3cr3t|abc/
    expect do
      expect do
        state.save
        state.restore
        write_state('cookies' => [saved_cookie('x', value: 's3cr3t')], 'local_storage' => { 'k' => 'abc' })
        state.reuse(valid: -> { false }) { nil }
      end.not_to output(leak).to_stdout
    end.not_to output(leak).to_stderr
  end

  describe 'unsupported or unusable files' do
    it 'warns once, naming the file, for another format' do
      write_state('format' => 2)
      expect { expect(state.restore).to be(false) }.to output(/\A\[login_state\] #{Regexp.escape(state_file)} has an unsupported format.*\n\z/).to_stderr
    end

    it 'stays silent for a missing, expired or other-origin file' do
      expect do
        state.fresh?
        write_state('origin' => 'https://other.test')
        state.fresh?
        write_state('saved_at' => (Time.now.utc - 7200).iso8601)
        state.fresh?
      end.not_to output.to_stderr
    end

    it 'retries a cookie the browser rejects without sameSite' do
      rejecting = SessionStateSpec::ManagedDriver.new(reject: ->(cookie) { cookie.key?(:sameSite) })
      write_state('cookies' => [saved_cookie('a', same_site: 'None')])
      expect(SessionState.new(rejecting).restore).to be(true)
      expect(rejecting.added.map { |c| [c[:name], c.key?(:sameSite)] }).to eq([['a', false]])
    end
  end

  describe '#reuse' do
    def run_reuse(**options)
      count = 0
      silence { state.reuse(**options) { count += 1 } }
      count
    end

    def silence
      original = $stderr
      $stderr = StringIO.new
      yield
    ensure
      $stderr = original
    end

    def warnings
      original = $stderr
      $stderr = StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = original
    end

    it 'logs in and saves when there is no file' do
      expect(run_reuse).to eq(1)
      expect(File).to exist(state_file)
      expect(driver.calls).not_to include(:delete_all_cookies)
    end

    it 'clears the restored cookies and storage before the fallback login' do
      managed = SessionStateSpec::ManagedDriver.new
      write_state('cookies' => [saved_cookie('a')], 'local_storage' => { 'k' => 'v' })
      silence { SessionState.new(managed).reuse(valid: -> { false }) { managed.calls << :login } }
      after_refresh = managed.calls.drop(managed.calls.index(:refresh) + 1)
      expect(after_refresh).to eq([:delete_all_cookies, [:write, 'localStorage'], [:write, 'sessionStorage'], :login])
      expect(managed.local).to eq({})
    end

    it 'clears a half-applied restore before the fallback login' do
      broken = SessionStateSpec::ManagedDriver.new(reject: ->(_cookie) { true })
      write_state('cookies' => [saved_cookie('a')])
      silence { SessionState.new(broken).reuse { broken.calls << :login } }
      expect(broken.calls.last(4)).to eq([:delete_all_cookies, [:write, 'localStorage'], [:write, 'sessionStorage'],
                                          :login])
    end

    it 'logs in without saving, with one warning, when the auth directory cannot be created' do
      FileUtils.mkdir_p('.raider')
      File.chmod(0o500, '.raider')
      count = 0
      output = warnings { expect(state.reuse { count += 1 }).to be(true) }
      expect(count).to eq(1)
      expect(output.lines).to match([start_with('[login_state] ')])
    ensure
      File.chmod(0o700, '.raider')
    end

    it 'logs in without saving, with one warning, when the lock cannot be opened' do
      FileUtils.mkdir_p(File.join('.raider', 'auth', 'user.lock'))
      count = 0
      output = warnings { expect(state.reuse { count += 1 }).to be(true) }
      expect(count).to eq(1)
      expect(output.lines).to match([start_with('[login_state] ')])
      expect(File).not_to exist(state_file)
    end

    it 'keeps the login, with one warning naming the file, when saving after it fails' do
      allow(driver).to receive(:execute_script).and_raise(Selenium::WebDriver::Error::JavascriptError, 'abc')
      count = 0
      output = warnings { expect(state.reuse { count += 1 }).to be(true) }
      expect(count).to eq(1)
      expect(output.lines).to match([include(state_file, 'JavascriptError')])
      expect(output).not_to include('abc')
    end

    it 'restores and skips the login when fresh and valid' do
      write_state
      expect(run_reuse(valid: -> { true })).to eq(0)
      expect(driver.calls).to include(:refresh)
    end

    it 'falls back once when valid returns false' do
      write_state('saved_at' => (Time.now.utc - 100).iso8601)
      before = Time.iso8601(saved['saved_at'])
      expect(run_reuse(valid: -> { false })).to eq(1)
      expect(Time.iso8601(saved['saved_at'])).to be > before
    end

    it 'falls back when the file is corrupt' do
      FileUtils.mkdir_p(File.dirname(state_file))
      File.write(state_file, '{"format":')
      expect(run_reuse).to eq(1)
      expect(saved['format']).to eq(1)
    end

    it 'falls back once, with one warning, when valid raises' do
      write_state
      count = 0
      expect { state.reuse(valid: -> { raise 'boom' }) { count += 1 } }.to output(/\A\[login_state\] validity check failed \(RuntimeError\), logging in again\n\z/).to_stderr
      expect(count).to eq(1)
    end

    it 'falls back once, with one warning, when restore raises' do
      write_state('cookies' => [saved_cookie('a')])
      broken = SessionStateSpec::FakeDriver.new(reject: ->(_cookie) { true })
      count = 0
      expect { SessionState.new(broken).reuse { count += 1 } }.to output(/\A\[login_state\] could not restore.*\n\z/).to_stderr
      expect(count).to eq(1)
    end

    it 'warns once for another format and logs in' do
      write_state('format' => 2)
      count = 0
      expect { state.reuse { count += 1 } }.to output(/\A\[login_state\] .*unsupported format.*\n\z/).to_stderr
      expect(count).to eq(1)
    end

    it 'RAIDER_LOGIN_STATE=off logs in and does not touch the disk' do
      stub_const('ENV', ENV.to_h.merge('RAIDER_LOGIN_STATE' => 'off'))
      expect(run_reuse).to eq(1)
      expect(File).not_to exist('.raider')
    end

    it 'RAIDER_LOGIN_STATE=refresh logs in even when fresh' do
      write_state('saved_at' => (Time.now.utc - 100).iso8601)
      before = Time.iso8601(saved['saved_at'])
      stub_const('ENV', ENV.to_h.merge('RAIDER_LOGIN_STATE' => 'refresh'))
      expect(run_reuse).to eq(1)
      expect(Time.iso8601(saved['saved_at'])).to be > before
    end

    it 'lets concurrent callers restore a fresh login at the same time' do
      write_state('cookies' => [saved_cookie('session')])
      arrived = Queue.new
      checked = Queue.new
      threads = Array.new(2) do
        Thread.new do
          valid = lambda do
            arrived << 1
            Timeout.timeout(2) { sleep 0.01 until arrived.size == 2 }
            checked << 1
          end
          SessionState.new(SessionStateSpec::FakeDriver.new(cookies:)).reuse(valid:) { raise 'logged in' }
        end
      end
      threads.each(&:join)
      expect(checked.size).to eq(2)
    end

    it 'restores a login another worker saved meanwhile, without a fallback warning' do
      write_state('cookies' => [saved_cookie('session')])
      checks = 0
      valid = lambda do
        checks += 1
        write_state('cookies' => [saved_cookie('session')], 'saved_at' => Time.now.utc.iso8601) if checks == 1
        checks > 1
      end
      logins = 0
      expect { state.reuse(valid:) { logins += 1 } }.not_to output.to_stderr
      expect([logins, checks]).to eq([0, 2])
    end

    it 'warns once when the second restore after a peer save is also invalid' do
      write_state('cookies' => [saved_cookie('session')])
      checks = 0
      valid = lambda do
        checks += 1
        write_state('cookies' => [saved_cookie('session')], 'saved_at' => Time.now.utc.iso8601) if checks == 1
        false
      end
      logins = 0
      expect { state.reuse(valid:) { logins += 1 } }
        .to output(/\A\[login_state\] login restored from \S+ is no longer valid, logging in again\n\z/).to_stderr
      expect(logins).to eq(1)
    end

    it 'serializes concurrent callers on the lock' do
      count = 0
      drivers = Array.new(2) { SessionStateSpec::FakeDriver.new(cookies:) }
      threads = drivers.map do |fake|
        Thread.new do
          SessionState.new(fake).reuse do
            sleep 0.2
            count += 1
          end
        end
      end
      threads.each(&:join)
      expect(count).to eq(1)
      expect(drivers.count { |fake| fake.calls.include?(:refresh) }).to eq(1)
    end
  end
end
