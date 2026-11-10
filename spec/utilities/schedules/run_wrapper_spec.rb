# frozen_string_literal: true

require 'json'
require 'stringio'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/run_wrapper'

# The fake spawner needs its calls, outcome and project next to the wrapper
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::RunWrapper do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-wrapper')) }
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:store) { RubyRaider::Schedules::ScheduleStore.new(project) }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:now) { Time.utc(2026, 11, 11, 8, 0, 0) }
  let(:calls) { [] }
  let(:notices) { [] }
  let(:notifier) do
    sent = notices
    Class.new { define_method(:notify) { |title, message| sent << [title, message] && false } }.new
  end
  # What the fake rspec run does: exit code, stopped, and the statuses of the run.json it writes (nil: none)
  let(:outcome) { { code: 0, stopped: false, statuses: %w[passed passed] } }
  let(:spawner) do
    lambda do |env, argv, chdir|
      calls << { env: env, argv: argv, chdir: chdir, running: File.exist?(File.join(dir, '.raider/schedules/running.json')) }
      write_run(outcome[:statuses]) if outcome[:statuses]
      [outcome[:code], outcome[:stopped]]
    end
  end
  let(:wrapper) { described_class.new(project, out: out, err: err, spawner: spawner, clock: -> { now }, notifier: notifier) }
  let(:folder) { File.join(dir, '.raider/schedules/nightly') }

  def write_run(statuses, started_at: '2026-11-11T08:00:01.000Z')
    results = File.join(dir, 'raider-results')
    FileUtils.mkdir_p(File.join(results, 'attachments'))
    File.write(File.join(results, 'run.json'), JSON.generate('run' => { 'started_at' => started_at }, 'results' => statuses.map { |status| { 'status' => status } }))
    File.write(File.join(results, 'index.html'), '<html>')
  end

  def schedule(name: 'nightly', **options)
    store.save(RubyRaider::Schedules::Schedule.build(project: project, name: name, every: 'day', at: '08:00', host_os: 'darwin', **options))
  end

  def lines = File.readlines(File.join(folder, 'runs.jsonl')).map { |line| JSON.parse(line) }

  before do
    FileUtils.mkdir_p(File.join(dir, 'spec'))
    File.write(File.join(dir, 'spec/login_spec.rb'), '')
    File.write(File.join(dir, 'spec/cart_spec.rb'), '')
    schedule
  end

  after { FileUtils.rm_rf(dir) }

  describe 'a passing run' do
    it 'runs bundle exec rspec with the scheduled ruby and bundle, from the project, with no path for all tests' do
      entry = store.find('nightly')

      expect(wrapper.run('nightly')).to eq(0)
      expect(calls.first[:argv]).to eq([entry.ruby, entry.bundle, 'exec', 'rspec'])
      expect([calls.first[:chdir], calls.first[:env]['BUNDLE_GEMFILE']]).to eq([dir, File.join(dir, 'Gemfile')])
    end

    it 'records the run line with counts, trigger and the report copy, and no messages' do
      wrapper.run('nightly')

      line = lines.last
      expect(line.keys).to eq(%w[run_id started_at finished_at status counts trigger results_dir report_copy])
      expect(line).to include('status' => 'passed', 'counts' => { 'total' => 2, 'passed' => 2, 'failed' => 0, 'skipped' => 0 },
                              'trigger' => 'manual', 'results_dir' => 'raider-results', 'report_copy' => '.raider/schedules/nightly/last',
                              'started_at' => '2026-11-11T08:00:00.000Z', 'finished_at' => '2026-11-11T08:00:00.000Z')
      expect(line['run_id']).to match(/\A[0-9a-f]{16}\z/)
      expect(Dir.children(File.join(folder, 'last')).sort).to eq(%w[attachments index.html run.json])
    end

    it 'prints one result line and does not notify' do
      schedule(notify: true)
      wrapper.run('nightly')

      expect([out.string, notices]).to eq(["Schedule nightly passed: 2 tests\n", []])
    end

    it 'holds running.json while rspec runs and removes it after' do
      wrapper.run('nightly')

      expect([calls.first[:running], File.exist?(File.join(dir, '.raider/schedules/running.json'))]).to eq([true, false])
    end

    it 'records a schedule trigger' do
      wrapper.run('nightly', trigger: 'schedule')

      expect(lines.last['trigger']).to eq('schedule')
    end
  end

  describe 'selection' do
    it 'passes one tag' do
      schedule(selection: RubyRaider::Schedules::Selection.new(kind: 'tag', tag: 'smoke'))
      wrapper.run('nightly')

      expect(calls.first[:argv].drop(2)).to eq(%w[exec rspec --tag smoke])
    end

    it 'passes the listed files' do
      schedule(selection: RubyRaider::Schedules::Selection.new(kind: 'files', files: %w[spec/login_spec.rb spec/cart_spec.rb]))
      wrapper.run('nightly')

      expect(calls.first[:argv].drop(2)).to eq(%w[exec rspec spec/login_spec.rb spec/cart_spec.rb])
    end
  end

  describe 'env' do
    around do |example|
      saved = %w[HEADLESS RAIDER_SHOW_BROWSER RETRY_COUNT RSPEC_RETRY_RETRY_COUNT].to_h { |key| [key, ENV.fetch(key, nil)] }
      example.run
    ensure
      saved.each { |key, value| ENV[key] = value }
    end

    def env_for(show_browser:, inherited:)
      ENV['HEADLESS'] = inherited
      ENV['RAIDER_SHOW_BROWSER'] = '1'
      ENV['RSPEC_RETRY_RETRY_COUNT'] = '9'
      schedule(show_browser: show_browser, retries: 2)
      wrapper.run('nightly')
      calls.last[:env].slice('HEADLESS', 'RAIDER_SHOW_BROWSER', 'RETRY_COUNT', 'RSPEC_RETRY_RETRY_COUNT')
    end

    hidden = { 'HEADLESS' => 'true', 'RAIDER_SHOW_BROWSER' => nil, 'RETRY_COUNT' => '3', 'RSPEC_RETRY_RETRY_COUNT' => nil }
    shown = { 'HEADLESS' => nil, 'RAIDER_SHOW_BROWSER' => '1', 'RETRY_COUNT' => '3', 'RSPEC_RETRY_RETRY_COUNT' => nil }

    { [false, nil] => hidden, [false, 'false'] => hidden, [true, nil] => shown, [true, 'true'] => shown }.each do |(show, inherited), env|
      it "sets #{env.compact} for show_browser #{show} with HEADLESS #{inherited.inspect} inherited" do
        expect(env_for(show_browser: show, inherited: inherited)).to eq(env)
      end
    end

    it 'counts tries: one with no retries' do
      wrapper.run('nightly')

      expect(calls.first[:env]['RETRY_COUNT']).to eq('1')
    end

    it 'never writes config/config.yml' do
      config = File.join(dir, 'config/config.yml')
      FileUtils.mkdir_p(File.dirname(config))
      File.write(config, "browser: chrome\nheadless: true\n")
      schedule(show_browser: true)
      wrapper.run('nightly')

      expect(File.binread(config)).to eq("browser: chrome\nheadless: true\n")
    end
  end

  describe 'a failing run' do
    let(:outcome) { { code: 1, stopped: false, statuses: %w[passed failed quarantined skipped] } }

    it 'exits 1, prints the failures and notifies when asked' do
      schedule(notify: true)

      expect(wrapper.run('nightly')).to eq(1)
      expect(out.string).to eq("Schedule nightly failed: 2 of 4 tests failed\n")
      expect(notices).to eq([['Ruby Raider: nightly failed', '2 of 4 tests failed']])
      expect(lines.last['counts']).to eq('total' => 4, 'passed' => 1, 'failed' => 2, 'skipped' => 1)
    end

    it 'does not notify without notify' do
      wrapper.run('nightly')

      expect(notices).to eq([])
    end
  end

  describe 'setup errors (exit 2)' do
    before { schedule(notify: true) }

    it 'is a setup error when rspec exits 1 without a report' do
      outcome.merge!(code: 1, statuses: nil)

      expect(wrapper.run('nightly')).to eq(2)
      expect(lines.last).to include('status' => 'setup_error', 'counts' => { 'total' => 0, 'passed' => 0, 'failed' => 0, 'skipped' => 0 })
      expect(lines.last).not_to have_key('report_copy')
      expect(notices).to eq([['Ruby Raider: nightly failed', 'Could not start: see the run output']])
      expect(out.string).to eq("Schedule nightly could not start: see the run output\n")
    end

    it 'points a scheduled run at its scheduler.log', skip: Gem.win_platform? do
      outcome.merge!(code: 1, statuses: nil)
      wrapper.run('nightly', trigger: 'schedule')

      expect(notices.last.last).to eq('Could not start: see .raider/schedules/nightly/scheduler.log')
    end

    it 'is a setup error when no example ran' do
      outcome.merge!(code: 0, statuses: [])

      expect(wrapper.run('nightly')).to eq(2)
    end

    it 'is a setup error when the run.json is an earlier run, which it keeps' do
      outcome.merge!(code: 1, statuses: nil)
      write_run(%w[failed], started_at: '2026-11-10T08:00:00.000Z')

      expect(wrapper.run('nightly')).to eq(2)
      expect([lines.last['status'], File.exist?(File.join(folder, 'last')), File.exist?(File.join(dir, 'raider-results/run.json'))]).to eq(['setup_error', false, true])
    end

    it 'is a setup error when rspec did not start' do
      outcome.merge!(code: nil, statuses: nil)

      expect(wrapper.run('nightly')).to eq(2)
    end

    it 'records a missing spec file before anything runs' do
      schedule(notify: true, selection: RubyRaider::Schedules::Selection.new(kind: 'files', files: %w[spec/login_spec.rb]))
      File.delete(File.join(dir, 'spec/login_spec.rb'))

      expect(wrapper.run('nightly')).to eq(2)
      expect([calls, lines.last['status']]).to eq([[], 'setup_error'])
      expect(out.string).to eq("Schedule nightly could not start: spec/login_spec.rb not found: remove the schedule or add it again\n")
      expect(notices).to eq([['Ruby Raider: nightly failed', 'Could not start: spec/login_spec.rb not found']])
      expect(File.exist?(File.join(dir, '.raider/schedules/running.json'))).to be(false)
    end

    it 'never changes the exit code for a notification that could not be shown' do
      outcome.merge!(code: 1, statuses: nil)

      expect(wrapper.run('nightly')).to eq(2)
      expect(notices.size).to eq(1)
    end
  end

  describe 'a stopped run' do
    let(:outcome) { { code: 1, stopped: true, statuses: %w[passed failed] } }

    it 'is a setup error even with failures, never notified' do
      schedule(notify: true)

      expect(wrapper.run('nightly')).to eq(2)
      expect([lines.last['status'], notices]).to eq(['setup_error', []])
      expect(out.string).to eq("Schedule nightly was stopped\n")
    end
  end

  describe 'a run line that cannot be written' do
    before do
      FileUtils.mkdir_p(folder)
      File.symlink(File.join(dir, 'elsewhere.jsonl'), File.join(folder, 'runs.jsonl'))
      schedule(notify: true)
    end

    it 'keeps a stop: not notified, still stopped' do
      outcome.merge!(code: 1, stopped: true)

      expect(wrapper.run('nightly')).to eq(2)
      expect([notices, out.string, File.exist?(File.join(dir, 'elsewhere.jsonl'))]).to eq([[], "Schedule nightly was stopped\n", false])
      expect(err.string).to include('Could not record the run')
    end

    it 'keeps the outcome of a run that passed' do
      expect(wrapper.run('nightly')).to eq(0)
    end
  end

  describe 'busy (exit 3, nothing spawned, raider-results untouched)' do
    before do
      schedule(notify: true)
      write_run(%w[failed])
    end

    def results_snapshot = Dir.glob('**/*', base: File.join(dir, 'raider-results')).sort.map { |path| [path, File.mtime(File.join(dir, 'raider-results', path))] }

    it 'is busy while another run holds the lock' do
      before = results_snapshot
      File.open(File.join(dir, '.raider/schedules/run.lock'), File::RDWR | File::CREAT, 0o600) do |held|
        held.flock(File::LOCK_EX)

        expect(wrapper.run('nightly')).to eq(3)
      end
      expect([calls, notices, lines.last['status'], results_snapshot]).to eq([[], [], 'busy', before])
      expect(out.string).to eq("Schedule nightly is already running\n")
    end

    it 'is busy while running.json names a live process' do
      File.write(File.join(dir, '.raider/schedules/running.json'), JSON.generate('pid' => Process.ppid))

      expect(wrapper.run('nightly')).to eq(3)
      expect(File.exist?(File.join(dir, '.raider/schedules/running.json'))).to be(true)
    end
  end

  describe 'refusals (Error, exit 2, no line)' do
    it 'refuses an unknown schedule' do
      expect { wrapper.run('nope') }.to raise_error(RubyRaider::Schedules::Error, /nope/) { |error| expect(error.exit_code).to eq(2) }
      expect(File.exist?(File.join(dir, '.raider/schedules/nope'))).to be(false)
    end

    it 'refuses an entry that no longer validates' do
      yml = File.join(dir, '.raider/schedules/schedules.yml')
      File.write(yml, File.read(yml).sub(/os_id: .*/, 'os_id: dev.rubyraider.schedule.0000000000.nightly'))

      expect { wrapper.run('nightly') }.to raise_error(RubyRaider::Schedules::Error)
      expect(calls).to eq([])
    end

    it 'refuses an unknown trigger' do
      expect { wrapper.run('nightly', trigger: 'desktop') }.to raise_error(RubyRaider::Schedules::Error, /trigger/)
    end
  end

  describe 'scheduler.log' do
    let(:log) { File.join(folder, 'scheduler.log') }

    before do
      FileUtils.mkdir_p(folder)
      File.write("#{log}.1", 'older')
    end

    it 'rotates a scheduled run log over 1 MB to scheduler.log.1' do
      File.write(log, 'x' * ((1024 * 1024) + 1))
      wrapper.run('nightly', trigger: 'schedule')

      expect([File.exist?(log), File.size("#{log}.1")]).to eq([false, (1024 * 1024) + 1])
    end

    it 'keeps a log of 1 MB or less, and any log on a manual run' do
      File.write(log, 'x' * (1024 * 1024))
      wrapper.run('nightly', trigger: 'schedule')
      File.write(log, 'x' * ((1024 * 1024) + 1))
      wrapper.run('nightly')

      expect([File.size(log), File.read("#{log}.1")]).to eq([(1024 * 1024) + 1, 'older'])
    end

    it 'does not rotate a linked log' do
      target = File.join(dir, 'big.log')
      File.write(target, 'x' * ((1024 * 1024) + 1))
      File.symlink(target, log)
      wrapper.run('nightly', trigger: 'schedule')

      expect([File.symlink?(log), File.read("#{log}.1")]).to eq([true, 'older'])
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
