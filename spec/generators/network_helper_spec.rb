# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'tmpdir'
require 'uri'
require_relative '../../lib/generators/helper_generator'

# Renders network_helper.tt for a selenium/rspec project and loads it.
module NetworkHelperRenderer
  TEMPLATE = File.expand_path('../../lib/generators/templates/helpers/network_helper.tt', __dir__)

  def render_and_load_network_helper
    generator = HelpersGenerator.new(%w[selenium rspec proj])
    rendered = ERB.new(File.read(TEMPLATE), trim_mode: '-').result(generator.instance_eval { binding })
    Dir.mktmpdir('network-helper') do |dir|
      path = File.join(dir, 'network_helper.rb')
      File.write(path, rendered)
      Object.send(:remove_const, :NetworkHelper) if Object.const_defined?(:NetworkHelper)
      load path
    end
  end
end

RSpec.describe 'NetworkHelper::Matcher' do
  include NetworkHelperRenderer

  before { render_and_load_network_helper }

  let(:matcher) { NetworkHelper::Matcher }

  def matches?(url, request_url, http_method = 'GET', **options)
    matcher.new(url, **options).match?(request_url, http_method)
  end

  describe '#match?' do
    it 'matches ** across hosts but not the query' do
      expect(matches?('**/api/users', 'https://a.test/api/users')).to be(true)
      expect(matches?('**/api/users', 'https://a.test/api/users?page=2')).to be(false)
      expect(matches?('**/api/users?*', 'https://a.test/api/users?page=2')).to be(true)
    end

    it 'stops * at a slash' do
      expect(matches?('https://shop.test/api/items/*', 'https://shop.test/api/items/7')).to be(true)
      expect(matches?('https://shop.test/api/items/*', 'https://shop.test/api/items/7/x')).to be(false)
    end

    it 'treats other characters literally' do
      expect(matches?('https://a.test/a.b', 'https://a.test/aXb')).to be(false)
      expect(matches?('https://a.test/a.b', 'https://a.test/a.b')).to be(true)
    end

    it 'matches a Regexp against the full URL' do
      expect(matches?(%r{/api/items/\d+$}, 'https://a.test/api/items/42')).to be(true)
    end

    it 'compares the method case-insensitively, nil matches all' do
      expect(matches?('**/api', 'https://a.test/api', 'GET', method: :post)).to be(false)
      expect(matches?('**/api', 'https://a.test/api', 'POST', method: :post)).to be(true)
      expect(matches?('**/api', 'https://a.test/api', 'DELETE')).to be(true)
    end

    it 'rejects a url that is neither String nor Regexp' do
      expect { matcher.new(42) }.to raise_error(ArgumentError)
    end
  end

  describe '#intercept_patterns' do
    it 'narrows to the literal parts of the glob' do
      expect(matcher.new('**/api/users').intercept_patterns).to be_nil
      expect(matcher.new('https://*.test/api').intercept_patterns).to be_nil
      expect(matcher.new('https://a.test/api/users?*').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'https', hostname: 'a.test', pathname: '/api/users' }])
      expect(matcher.new('https://shop.test/api/*').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'https', hostname: 'shop.test' }])
      expect(matcher.new('http://127.0.0.1:4567/api').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'http', hostname: '127.0.0.1', port: '4567', pathname: '/api' }])
    end

    it 'does not narrow on an IPv6 host, userinfo, or a path BiDi patterns reject' do
      expect(matcher.new('http://[::1]:8080/api').intercept_patterns).to be_nil
      expect(matcher.new('https://u@a.test/x').intercept_patterns).to be_nil
      expect(matcher.new('https://a.test/a(b)').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'https', hostname: 'a.test' }])
      expect(matcher.new('https://a.test/a{b}').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'https', hostname: 'a.test' }])
    end

    it 'is nil when nothing literal is left' do
      expect(matcher.new(/x/).intercept_patterns).to be_nil
      expect(matcher.new('**').intercept_patterns).to be_nil
    end
  end

  describe 'narrowing never misses a matching URL' do
    let(:urls) do
      %w[https://a.test/api/users https://a.test/api/users?page=2 https://shop.test/api/items/7
         http://127.0.0.1:4567/api http://127.0.0.1:4567/api/x https://b.test/x/api/users https://a.test]
    end
    let(:globs) do
      ['**/api/users', '**/api/users?*', 'https://a.test/api/users?*', 'https://shop.test/api/*',
       'http://127.0.0.1:4567/api', 'http://127.0.0.1:4567/**', 'https://*.test/api/users', '**', 'https://a.test**']
    end

    def covered?(pattern, uri)
      { protocol: uri.scheme, hostname: uri.host, port: uri.port.to_s, pathname: uri.path }.all? do |key, value|
        !pattern.key?(key) || pattern[key] == value
      end
    end

    it 'keeps every URL the glob matches inside a narrowed pattern' do
      globs.each do |glob|
        matcher_for_glob = matcher.new(glob)
        patterns = matcher_for_glob.intercept_patterns
        urls.select { |url| matcher_for_glob.match?(url, 'GET') }.each do |url|
          next if patterns.nil?

          uri = URI(url)
          expect(patterns.any? { |pattern| covered?(pattern, uri) }).to be(true), "#{glob} narrows past #{url}"
        end
      end
    end
  end
end

# Stands in for Selenium::WebDriver::BiDi (4.52), like FakeTraceBidi: emit runs each callback on its own thread.
class FakeNetworkBidi
  attr_reader :subscribed, :commands
  attr_accessor :failure, :command_failure

  def initialize
    @subscribed = []
    @callbacks = Hash.new { |hash, event| hash[event] = [] }
    @commands = []
    @lock = Mutex.new
  end

  def session
    self
  end

  def subscribe(events, _browsing_contexts = nil)
    raise failure if failure

    @subscribed << Array(events)
    {}
  end

  def add_callback(event, &block)
    @callbacks[event] << block
    block.object_id
  end

  def send_cmd(method, **params)
    raise command_failure if command_failure && method != 'network.addIntercept'

    @lock.synchronize do
      @commands << [method, params]
      method == 'network.addIntercept' ? { 'intercept' => "i-#{named('network.addIntercept').size}" } : {}
    end
  end

  def emit(event, params)
    @callbacks[event].map { |callback| Thread.new { callback.call(params) } }.each(&:join)
  end

  def named(method)
    @commands.select { |name, _| name == method }.map(&:last)
  end
end

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/MultipleExpectations
RSpec.describe 'NetworkHelper::Router' do
  include NetworkHelperRenderer

  let(:bidi) { FakeNetworkBidi.new }
  let(:browser) { 'chrome' }
  let(:fake_driver) do
    double('driver', bidi: bidi, capabilities: double('caps', browser_name: browser))
  end
  let(:host) do
    fake = fake_driver
    Class.new do
      include NetworkHelper

      define_method(:driver) { fake }
    end.new
  end
  let(:accept) { [{ 'name' => 'Accept', 'value' => { 'type' => 'string', 'value' => '*/*' } }] }

  before do
    render_and_load_network_helper
    ENV.delete('BIDI')
  end

  after do
    NetworkHelper.observer = nil
    ENV.delete('BIDI')
  end

  def event(id: 'r1', url: 'https://a.test/api/users', http_method: 'GET', intercepts: ['i-1'], blocked: true,
            headers: accept)
    { 'isBlocked' => blocked, 'intercepts' => intercepts, 'redirectCount' => 0,
      'request' => { 'request' => id, 'url' => url, 'method' => http_method, 'headers' => headers } }
  end

  def emit(**options)
    bidi.emit('network.beforeRequestSent', event(**options))
  end

  def header_pairs(params)
    params[:headers].to_h { |header| [header[:name], header[:value][:value]] }
  end

  it 'subscribes and adds one callback per driver' do
    host.mock_request('**/a')
    host.mock_request('**/b')
    expect(bidi.subscribed).to eq([['network.beforeRequestSent']])
    expect(bidi.named('network.addIntercept').size).to eq(2)
  end

  it 'adds the intercept without urlPatterns when nothing is literal, with them otherwise' do
    host.mock_request('**/a')
    host.mock_request('https://a.test/x')
    first, second = bidi.named('network.addIntercept')
    expect(first).to eq(phases: ['beforeRequestSent'])
    expect(second).to include(urlPatterns: [{ type: 'pattern', protocol: 'https', hostname: 'a.test', pathname: '/x' }])
  end

  it 'fulfils with json' do
    host.mock_request('**/api/users', json: { users: [] })
    emit
    params = bidi.named('network.provideResponse').first
    expect(params).to include(request: 'r1', statusCode: 200, reasonPhrase: 'OK')
    expect(header_pairs(params)).to eq('Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*')
    expect(params[:body]).to eq(type: 'base64', value: ['{"users":[]}'].pack('m0'))
  end

  it 'keeps a header or content_type given for json' do
    host.mock_request('**/a', json: {}, headers: { 'content-type' => 'application/vnd.api+json' })
    host.mock_request('**/b', json: {}, content_type: 'text/x-json', status: 201)
    emit(url: 'https://a.test/a')
    emit(id: 'r2', url: 'https://a.test/b', intercepts: ['i-2'])
    first, second = bidi.named('network.provideResponse')
    expect(header_pairs(first)).to include('content-type' => 'application/vnd.api+json')
    expect(header_pairs(second)).to include('Content-Type' => 'text/x-json')
    expect(second).to include(statusCode: 201, reasonPhrase: 'Created')
  end

  it 'sends body bytes exactly' do
    host.mock_request('**/api/users', body: "\xFF\x00é".b, status: 201)
    emit
    params = bidi.named('network.provideResponse').first
    expect(params[:body][:value].unpack1('m0')).to eq("\xFF\x00é".b)
    expect(params[:reasonPhrase]).to eq('Created')
  end

  it 'rejects a block given together with a response' do
    [{ status: 500 }, { json: {} }, { body: 'x' }, { headers: { 'a' => 'b' } }, { content_type: 'text/plain' }].each do |options|
      expect { host.mock_request('**/a', **options) { :continue } }.to raise_error(ArgumentError, /either a block or a response/)
    end
    expect { host.mock_request('**/a') { :continue } }.not_to raise_error
  end

  it 'rejects a status outside 100..599' do
    expect { host.mock_request('**/a', status: 999) }.to raise_error(ArgumentError, /100..599/)
    expect { host.mock_request('**/a', status: 99) }.to raise_error(ArgumentError)
  end

  it 'falls back to failRequest when provideResponse raises' do
    host.mock_request('**/api/users', json: {})
    allow(bidi).to receive(:send_cmd).and_wrap_original do |original, method, **params|
      raise 'gone' if method == 'network.provideResponse'

      original.call(method, **params)
    end
    emit
    expect(bidi.named('network.failRequest')).to eq([{ request: 'r1' }])
  end

  it 'rejects json and body together' do
    expect { host.mock_request('**/a', json: {}, body: 'x') }.to raise_error(ArgumentError)
  end

  it 'block_request fails the request' do
    host.block_request('**/api/users')
    emit
    expect(bidi.named('network.failRequest')).to eq([{ request: 'r1' }])
  end

  it 'continues unmatched requests with only the request id' do
    host.mock_request('**/other')
    emit
    expect(bidi.named('network.continueRequest')).to eq([{ request: 'r1' }])
  end

  it 'ignores events that are not ours' do
    host.block_request('**/api/users')
    emit(blocked: false)
    emit(intercepts: ['other'])
    expect(bidi.commands.map(&:first)).to eq(['network.addIntercept'])
  end

  it 'lets the newest mock win' do
    host.mock_request('**/api/users', status: 200)
    host.mock_request('**/api/*', status: 404)
    emit
    expect(bidi.named('network.provideResponse').first).to include(statusCode: 404)
  end

  it 'filters by method' do
    host.mock_request('**/api/users', method: :post, status: 201)
    emit
    emit(id: 'r2', http_method: 'POST')
    expect(bidi.named('network.continueRequest')).to eq([{ request: 'r1' }])
    expect(bidi.named('network.provideResponse').first).to include(request: 'r2', statusCode: 201)
  end

  describe 'block form' do
    it 'fulfils with a returned Hash' do
      host.mock_request('**/api/users') { |request| { status: 202, body: request.method } }
      emit
      params = bidi.named('network.provideResponse').first
      expect(params).to include(statusCode: 202)
      expect(params[:body][:value].unpack1('m0')).to eq('GET')
    end

    it 'continues, and continues with headers merged case-insensitively' do
      host.mock_request('**/a') { :continue }
      host.mock_request('**/b') { { continue: { headers: { 'x-a' => 'b', 'accept' => 'text/html' } } } }
      emit(url: 'https://a.test/a')
      emit(id: 'r2', url: 'https://a.test/b', intercepts: ['i-2'])
      first, second = bidi.named('network.continueRequest')
      expect(first).to eq(request: 'r1')
      expect(second[:request]).to eq('r2')
      expect(header_pairs(second)).to eq('x-a' => 'b', 'accept' => 'text/html')
    end

    it 'keeps the original headers when continuing with new ones' do
      host.mock_request('**/a') { { continue: { headers: { 'x-a' => 'b' } } } }
      emit(url: 'https://a.test/a')
      expect(header_pairs(bidi.named('network.continueRequest').first)).to eq('Accept' => '*/*', 'x-a' => 'b')
    end

    it 'fails the request and raises later when the block raises' do
      host.mock_request('**/api/users') { raise ArgumentError, 'boom' }
      emit
      expect(bidi.named('network.failRequest')).to eq([{ request: 'r1' }])
      expect { host.mock_request('**/x') }.to raise_error(NetworkHelper::MockError, %r{api/users raised ArgumentError: boom}) do |error|
        expect(error.cause).to be_a(ArgumentError)
      end
    end

    it 'hands the error to finish instead when it comes first' do
      host.mock_request('**/api/users') { raise 'boom' }
      emit
      error = NetworkHelper.finish(fake_driver)
      expect(error).to be_a(NetworkHelper::MockError)
      expect(error.cause.message).to eq('boom')
      expect(NetworkHelper.finish(fake_driver)).to be_nil
    end

    it 'catches non-StandardError exceptions such as failed expectations' do
      custom = Class.new(Exception) { def message = 'expectation not met' } # rubocop:disable Lint/InheritException
      host.mock_request('**/api/users') { raise custom }
      emit
      expect(bidi.named('network.failRequest')).to eq([{ request: 'r1' }])
      expect { host.mock_request('**/x') }.to raise_error(NetworkHelper::MockError, /expectation not met/) do |error|
        expect(error.cause).to be_a(custom)
      end
    end

    it 'includes the reason when a returned Hash is rejected' do
      host.mock_request('**/api/users') { { json: {}, body: 'x' } }
      emit
      expect { host.clear_mocks }.to raise_error(NetworkHelper::MockError, /returned.*not both/)
    end

    it 'rejects a returned status out of range' do
      host.mock_request('**/api/users') { { status: 700 } }
      emit
      expect(bidi.named('network.failRequest').size).to eq(1)
      expect { host.clear_mocks }.to raise_error(NetworkHelper::MockError, /returned.*100..599/)
    end

    it 'treats a junk result as an error' do
      host.mock_request('**/api/users') { 42 }
      emit
      expect(bidi.named('network.failRequest').size).to eq(1)
      expect { host.clear_mocks }.to raise_error(NetworkHelper::MockError, /returned 42/)
    end

    it 'with a stored error fails a matching request but continues an unmatched one' do
      host.mock_request('https://a.test/api/users') { raise 'boom' }
      emit
      emit(id: 'r2', url: 'https://a.test/other')
      emit(id: 'r3', url: 'https://a.test/api/users')
      expect(bidi.named('network.failRequest').map { |p| p[:request] }).to eq(%w[r1 r3])
      expect(bidi.named('network.continueRequest')).to eq([{ request: 'r2' }])
    end

    it 'turns a returned Hash with bad types into a MockError' do
      [{ headers: nil }, { headers: 'x' }, { status: 'abc' }, { continue: { headers: 'x' } }].each_with_index do |result, n|
        host.mock_request("**/bad#{n}") { result }
        emit(id: "b#{n}", url: "https://a.test/bad#{n}", intercepts: ['i-1'])
        expect(bidi.named('network.failRequest').map { |p| p[:request] }).to include("b#{n}")
        expect { host.clear_mocks }.to raise_error(NetworkHelper::MockError, /returned/)
        NetworkHelper.finish(fake_driver)
      end
    end

    it 'keeps only the first error and fails later requests' do
      host.mock_request('**/api/users') { 42 }
      emit
      emit(id: 'r2')
      expect(bidi.named('network.failRequest').size).to eq(2)
      expect { host.remove_mock(nil) }.to raise_error(NetworkHelper::MockError, /returned 42/)
    end
  end

  it 'answers exactly once per request under concurrency' do
    host.mock_request('**/api/users', json: {})
    host.mock_request('**/slow') { |request| request.url.empty? ? :fail : { status: 204 } }
    threads = Array.new(50) { |n| Thread.new { emit(id: "r#{n}", url: n.even? ? 'https://a.test/api/users' : 'https://a.test/slow', intercepts: ['i-2']) } }
    threads.each(&:join)
    answered = bidi.commands.select { |name, _| name.match?(/provideResponse|failRequest|continueRequest/) }
    expect(answered.size).to eq(50)
    expect(answered.map { |_, params| params[:request] }.uniq.size).to eq(50)
  end

  describe 'CORS' do
    def sent(pairs)
      pairs.map { |name, value| { 'name' => name, 'value' => { 'type' => 'string', 'value' => value } } }
    end

    it 'adds CORS headers for a cross-origin request' do
      host.mock_request('**/api/users', json: {})
      emit(headers: sent('Origin' => 'https://app.test'))
      expect(header_pairs(bidi.named('network.provideResponse').first)).to include(
        'Access-Control-Allow-Origin' => 'https://app.test', 'Access-Control-Allow-Credentials' => 'true'
      )
    end

    it "uses the Referer's origin when the browser pauses the request before adding Origin (Chrome)" do
      host.mock_request('**/api/users', json: {})
      emit(headers: sent('Referer' => 'https://app.test/some/page'))
      expect(header_pairs(bidi.named('network.provideResponse').first)).to include(
        'Access-Control-Allow-Origin' => 'https://app.test'
      )
    end

    it 'sends Allow-Origin * without credentials when no Origin or Referer is known' do
      host.mock_request('**/api/users', json: {})
      emit
      pairs = header_pairs(bidi.named('network.provideResponse').first)
      expect(pairs).to include('Access-Control-Allow-Origin' => '*')
      expect(pairs.keys).not_to include('Access-Control-Allow-Credentials')
    end

    it 'keeps the mock Allow-Origin when no origin is known' do
      host.mock_request('**/api/users', json: {}, headers: { 'access-control-allow-origin' => 'https://x.test' })
      emit
      expect(header_pairs(bidi.named('network.provideResponse').first).keys).to eq(%w[access-control-allow-origin Content-Type])
    end

    it 'answers a preflight with * and no credentials when no origin is known' do
      host.mock_request('**/api/users', json: {})
      emit(http_method: 'OPTIONS', headers: sent('Access-Control-Request-Method' => 'GET'))
      pairs = header_pairs(bidi.named('network.provideResponse').first)
      expect(pairs).to include('Access-Control-Allow-Origin' => '*', 'Access-Control-Allow-Methods' => 'GET')
      expect(pairs.keys).not_to include('Access-Control-Allow-Credentials')
    end

    it 'adds none when the Referer is same-origin' do
      host.mock_request('**/api/users', json: {})
      emit(headers: sent('Referer' => 'https://a.test/page'))
      expect(header_pairs(bidi.named('network.provideResponse').first).keys).to eq(['Content-Type'])
    end

    it 'adds none for same-origin' do
      host.mock_request('**/api/users', json: {})
      emit(headers: sent('Origin' => 'https://a.test'))
      expect(header_pairs(bidi.named('network.provideResponse').first).keys).to eq(['Content-Type'])
    end

    it "keeps the mock's own Access-Control-Allow-Origin" do
      host.mock_request('**/api/users', json: {}, headers: { 'access-control-allow-origin' => '*' })
      emit(headers: sent('Origin' => 'https://app.test'))
      pairs = header_pairs(bidi.named('network.provideResponse').first)
      expect(pairs).to include('access-control-allow-origin' => '*', 'Access-Control-Allow-Credentials' => 'true')
      expect(pairs).not_to include('Access-Control-Allow-Origin')
    end

    it 'answers a preflight with 204 echoing method and headers' do
      mock = host.mock_request('**/api/users', method: 'POST', json: {})
      NetworkHelper.observer = double('observer').tap { |o| expect(o).not_to receive(:request_mocked) }
      emit(http_method: 'OPTIONS', headers: sent('Origin' => 'https://app.test', 'Access-Control-Request-Method' => 'POST',
                                                 'Access-Control-Request-Headers' => 'content-type'))
      params = bidi.named('network.provideResponse').first
      expect(params).to include(statusCode: 204)
      expect(header_pairs(params)).to eq('Access-Control-Allow-Methods' => 'POST', 'Access-Control-Allow-Headers' => 'content-type',
                                         'Access-Control-Allow-Origin' => 'https://app.test',
                                         'Access-Control-Allow-Credentials' => 'true')
      expect(mock).not_to be_called
    end

    it 'omits Allow-Headers when none were requested' do
      host.mock_request('**/api/users', json: {})
      emit(http_method: 'OPTIONS', headers: sent('Origin' => 'https://app.test', 'Access-Control-Request-Method' => 'GET'))
      expect(header_pairs(bidi.named('network.provideResponse').first).keys).not_to include('Access-Control-Allow-Headers')
    end

    it "a mock with method: 'OPTIONS' answers the preflight itself" do
      host.mock_request('**/api/users', json: {})
      host.mock_request('**/api/users', method: 'OPTIONS', status: 200, body: 'mine')
      emit(http_method: 'OPTIONS', intercepts: ['i-2'],
           headers: sent('Origin' => 'https://app.test', 'Access-Control-Request-Method' => 'GET'))
      params = bidi.named('network.provideResponse').first
      expect(params).to include(statusCode: 200, body: { type: 'base64', value: ['mine'].pack('m0') })
    end

    it 'preflight to an unmatched URL is continued' do
      host.mock_request('**/api/users', json: {})
      emit(url: 'https://a.test/other', http_method: 'OPTIONS',
           headers: sent('Origin' => 'https://app.test', 'Access-Control-Request-Method' => 'GET'))
      expect(bidi.named('network.provideResponse')).to be_empty
      expect(bidi.named('network.continueRequest').size).to eq(1)
    end
  end

  it 'records calls, frozen, with lowercase headers' do
    mock = host.mock_request('**/api/users', json: {})
    expect(mock).not_to be_called
    emit
    expect(mock).to be_called
    expect(mock.url).to eq('**/api/users')
    expect(mock.calls.map(&:url)).to eq(['https://a.test/api/users'])
    expect(mock.calls.first.headers).to eq('accept' => '*/*')
    expect(mock.calls).to be_frozen
    expect(mock.calls.first).to be_frozen
  end

  describe 'observer' do
    let(:seen) { [] }

    before do
      log = seen
      commands = bidi.commands
      NetworkHelper.observer = Class.new do
        define_method(:request_mocked) do |**event|
          log << [event, commands.map(&:first)]
        end
      end.new
    end

    it 'is told before the answer' do
      host.mock_request('**/api/users', json: {})
      emit
      event, commands = seen.first
      expect(event).to eq(request_id: 'r1', redirect_count: 0, outcome: 'fulfilled', status: 200)
      expect(commands).not_to include('network.provideResponse')
    end

    it 'reports failed with no status, and not continue' do
      host.block_request('**/api/users')
      host.mock_request('**/other')
      emit
      emit(id: 'r2', url: 'https://a.test/nothing')
      expect(seen.map(&:first)).to eq([{ request_id: 'r1', redirect_count: 0, outcome: 'failed', status: nil }])
    end

    it 'does not stop the answer when it raises' do
      NetworkHelper.observer = Class.new do
        def request_mocked(**)
          raise 'nope'
        end
      end.new
      host.mock_request('**/api/users', json: {})
      emit
      expect(bidi.named('network.provideResponse').size).to eq(1)
    end
  end

  describe 'removal' do
    it 'remove_mock removes that intercept' do
      mock = host.mock_request('**/a')
      host.mock_request('**/b')
      host.remove_mock(mock)
      expect(bidi.named('network.removeIntercept')).to eq([{ intercept: 'i-1' }])
    end

    it 'finish removes every intercept' do
      host.mock_request('**/a')
      host.mock_request('**/b')
      expect(NetworkHelper.finish(fake_driver)).to be_nil
      expect(bidi.named('network.removeIntercept')).to eq([{ intercept: 'i-1' }, { intercept: 'i-2' }])
    end

    it 'finish returns nil without a router and never raises' do
      expect(NetworkHelper.finish(fake_driver)).to be_nil
      host.mock_request('**/a')
      bidi.command_failure = RuntimeError.new('gone')
      expect(NetworkHelper.finish(fake_driver)).to be_nil
    end

    it 'clear_mocks and remove_mock do nothing without a router' do
      expect(host.clear_mocks).to be_nil
      expect(bidi.commands).to be_empty
    end
  end

  describe 'Unavailable' do
    it 'is raised for safari' do
      allow(fake_driver.capabilities).to receive(:browser_name).and_return('safari')
      expect { host.mock_request('**/a') }.to raise_error(NetworkHelper::Unavailable, /safari/)
    end

    it 'names BIDI=off' do
      ENV['BIDI'] = 'off'
      expect { host.block_request('**/a') }.to raise_error(NetworkHelper::Unavailable, /BIDI=off/)
    end

    it 'is raised when subscribe fails' do
      bidi.failure = RuntimeError.new('no socket')
      expect { host.mock_request('**/a') }.to raise_error(NetworkHelper::Unavailable, /chrome.*no socket/)
    end
  end

  it 'adds exactly four public methods' do
    expect(NetworkHelper.public_instance_methods(false).sort).to eq(%i[block_request clear_mocks mock_request remove_mock])
    expect(NetworkHelper.private_instance_methods(false)).to be_empty
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/MultipleExpectations
