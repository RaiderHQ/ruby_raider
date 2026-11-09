# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'json'
require 'open3'
require 'time'
require 'tmpdir'

# Runs flows/support/run.rb and flows/flow_helper.rb, as `raider flow init` writes them, under a real
# rspec process. helpers/spec_helper.rb is a stand-in with no browser and no raider_reporter.
RSpec.describe 'flow run lifecycle' do
  templates = File.expand_path('../../../lib/generators/templates/flows', __dir__)

  stub_spec_helper = <<~RUBY
    # frozen_string_literal: true

    require 'json'
    require 'rspec'

    module RaiderReporter
      Config = Struct.new(:output_dir, :clean_output_dir)
      def self.configuration = (@configuration ||= Config.new)
      def self.configure = yield(configuration)
    end

    module DriverHelper
      def driver
        raise 'the driver could not start' if ENV['FAKE_DRIVER_FAIL']

        @driver ||= Object.new
      end
    end

    RSpec.configure do |config|
      config.include(DriverHelper)
      config.before(:each) { driver }
      # The real reporter writes run.json when it closes; the desktop sidecar names the failed step there
      config.after(:suite) do
        dir = RaiderReporter.configuration.output_dir
        steps = { 'items' => [{ 'id' => 's1', 'title' => 'open' }, { 'id' => 's2', 'title' => 'click "Export"' }], 'failed' => 1 }
        results = [{ 'file_path' => 'flows/recorded_flow.rb', 'status' => 'failed', 'steps' => steps }]
        File.write(File.join(dir, 'run.json'), JSON.generate('results' => results)) if dir && ENV['FAKE_STEPS']
      end
    end
  RUBY

  flows = {
    'ok' => <<~RUBY,
      require_relative 'flow_helper'

      RSpec.describe 'ok' do
        it 'runs every step' do
          driver
          puts "headless=\#{ENV.fetch('HEADLESS', 'unset')} who=\#{flow_input('who', 'nobody')}"
          puts "secret loaded=\#{ENV['RAIDER_SECRET_TOKEN'] == 'hunter2'}"
        end
      end
    RUBY
    'broken' => <<~RUBY,
      require_relative 'flow_helper'

      RSpec.describe 'broken' do
        it 'downloads the report' do
          driver
          driver
          raise 'no such element: { id: "export" } (waited 10s)'
        end
      end
    RUBY
    'recorded' => <<~RUBY,
      require_relative 'flow_helper'

      RSpec.describe 'recorded' do
        it 'exports' do
          raise 'no such element'
        end
      end
    RUBY
    'leaky' => <<~RUBY,
      require_relative 'flow_helper'

      RSpec.describe 'leaky' do
        it "types \#{ENV.fetch('RAIDER_SECRET_TOKEN', 'x')} somewhere" do
          raise 'failed'
        end
      end
    RUBY
    'unloadable' => <<~RUBY
      require_relative 'flow_helper'

      UndefinedConstant.call
    RUBY
  }

  let(:dir) { File.realpath(Dir.mktmpdir('flow-lifecycle')) }

  before do
    render = ->(name) { ERB.new(File.read(File.join(templates, name)), trim_mode: '-').result }
    FileUtils.mkdir_p(File.join(dir, 'flows/support'))
    FileUtils.mkdir_p(File.join(dir, 'helpers'))
    File.write(File.join(dir, 'flows/flow_helper.rb'), render.call('flow_helper.tt'))
    File.write(File.join(dir, 'flows/support/run.rb'), render.call('run.tt'))
    File.write(File.join(dir, 'helpers/spec_helper.rb'), stub_spec_helper)
    File.write(File.join(dir, '.rspec'), "-I .\n--require helpers/spec_helper\n")
    flows.each { |name, source| File.write(File.join(dir, "flows/#{name}_flow.rb"), source) }
  end

  after { FileUtils.rm_rf(dir) }

  # Unsets the variables the test process may carry that would change a run
  def clean_env
    %w[HEADLESS RAIDER_FLOW_NAME RAIDER_FLOW_HEADED RAIDER_FLOW_ATTEMPT RAIDER_FLOW_TRIGGER RAIDER_FLOW_RUN_ID
       RAIDER_SECRET_TOKEN RAIDER_INPUT_WHO FAKE_DRIVER_FAIL FAKE_STEPS].to_h { |key| [key, nil] }
  end

  def run_flow(name, env = {})
    out, err, status = Open3.capture3(clean_env.merge(env), RbConfig.ruby, '-S', 'rspec', "flows/#{name}_flow.rb", chdir: dir)
    [out + err, status.exitstatus]
  end

  def log(name)
    file = File.join(dir, ".raider/flows/#{name}/runs.jsonl")
    File.exist?(file) ? File.readlines(file).map { |line| JSON.parse(line) } : []
  end

  def mode(relative) = File.stat(File.join(dir, relative)).mode & 0o777

  def write_env_file(content, permissions)
    FileUtils.mkdir_p(File.join(dir, '.raider/flows'))
    File.write(File.join(dir, '.raider/flows/env'), content)
    File.chmod(permissions, File.join(dir, '.raider/flows/env'))
  end

  it 'records a completed run with its results folder, headless by default', :aggregate_failures do
    output, code = run_flow('ok', 'RAIDER_INPUT_WHO' => 'ada')
    line = log('ok').last

    expect(code).to eq(0)
    expect(output).to include('headless=true who=ada')
    expect(line).to include('status' => 'completed', 'attempt' => 1, 'trigger' => 'manual')
    expect(line['results_dir']).to match(%r{\Aflow-results/ok/\d{8}T\d{6}Z\z})
    expect(File).to be_directory(File.join(dir, line['results_dir']))
    expect(Time.iso8601(line['finished_at'])).to be >= Time.iso8601(line['started_at'])
  end

  it 'keeps the run log and lock private' do
    run_flow('ok')

    expect([mode('.raider/flows'), mode('.raider/flows/ok'), mode('.raider/flows/ok/runs.jsonl'), mode('.raider/flows/ok.lock')])
      .to eq([0o700, 0o700, 0o600, 0o600])
  end

  it 'opens the browser when RAIDER_FLOW_HEADED=1' do
    output, = run_flow('ok', 'RAIDER_FLOW_HEADED' => '1')

    expect(output).to include('headless=unset')
  end

  it 'takes the attempt, trigger and run id from the wrapper' do
    run_flow('ok', 'RAIDER_FLOW_ATTEMPT' => '2', 'RAIDER_FLOW_TRIGGER' => 'schedule', 'RAIDER_FLOW_RUN_ID' => 'abcdef0123456789')

    expect(log('ok').last).to include('attempt' => 2, 'trigger' => 'schedule', 'run_id' => 'abcdef0123456789')
  end

  it 'falls back to manual for an unknown trigger and drops a malformed run id' do
    run_flow('ok', 'RAIDER_FLOW_TRIGGER' => 'cron; rm -rf /', 'RAIDER_FLOW_RUN_ID' => '../x')

    expect(log('ok').last).to include('trigger' => 'manual').and(satisfy { |line| !line.key?('run_id') })
  end

  it 'records a failed step with its line in the flow file' do
    _output, code = run_flow('broken')
    line = log('broken').last

    expect(code).to eq(1)
    expect(line).to include('status' => 'failed', 'failed_step' => { 'title' => 'downloads the report', 'line' => 7 })
  end

  it 'names the recorded step when the report has the desktop step map' do
    run_flow('recorded', 'FAKE_STEPS' => '1')

    expect(log('recorded').last['failed_step']).to eq('number' => 2, 'title' => 'click "Export"', 'line' => 5)
  end

  it 'records a setup error when the driver fails before the first step' do
    _output, code = run_flow('ok', 'FAKE_DRIVER_FAIL' => '1')

    expect(code).to eq(1)
    expect(log('ok').last).to include('status' => 'setup_error').and(satisfy { |line| !line.key?('failed_step') })
  end

  it 'records a setup error when the flow file does not load' do
    _output, code = run_flow('unloadable')

    expect(code).not_to eq(0)
    expect(log('unloadable').last['status']).to eq('setup_error')
  end

  it 'refuses a RAIDER_FLOW_NAME that is not the flow being run' do
    output, code = run_flow('ok', 'RAIDER_FLOW_NAME' => 'other')

    expect(code).not_to eq(0)
    expect(output).to include('RAIDER_FLOW_NAME is "other" but the flow is "ok"')
    expect(log('ok')).to be_empty
  end

  it 'exits 3 with one busy line when another run holds the lock, and never waits' do
    FileUtils.mkdir_p(File.join(dir, '.raider/flows'))
    File.open(File.join(dir, '.raider/flows/ok.lock'), File::RDWR | File::CREAT, 0o600) do |held|
      held.flock(File::LOCK_EX)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      output, code = run_flow('ok')

      expect(code).to eq(3)
      expect(output).to include('ok is already running')
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 30
    end
    expect(log('ok').map { |line| line['status'] }).to eq(['busy'])
    expect(log('ok').last['results_dir']).to be_nil
  end

  it 'releases the lock when the run ends' do
    run_flow('ok')
    _output, code = run_flow('ok')

    expect(code).to eq(0)
    expect(log('ok').map { |line| line['status'] }).to eq(%w[completed completed])
  end

  context 'with the flow env file' do
    it 'loads a 0600 file without printing its values' do
      write_env_file("# secrets\nRAIDER_SECRET_TOKEN=\"hunter2\"\n\nbad line\n", 0o600)

      output, = run_flow('ok')

      expect(output).to include('secret loaded=true', '.raider/flows/env line 4 ignored: expected KEY=value')
      expect(output).not_to include('hunter2')
      expect(File.read(File.join(dir, '.raider/flows/ok/runs.jsonl'))).not_to include('hunter2')
    end

    it 'ignores a 0644 file with a warning' do
      write_env_file("RAIDER_SECRET_TOKEN=hunter2\n", 0o644)

      output, code = run_flow('ok')

      expect(code).to eq(0)
      expect(output).to include('ignored .raider/flows/env: permissions must be 600', 'secret loaded=false')
    end

    it 'ignores a link to a file elsewhere' do
      target = File.join(dir, 'elsewhere')
      File.write(target, "RAIDER_SECRET_TOKEN=hunter2\n")
      File.chmod(0o600, target)
      FileUtils.mkdir_p(File.join(dir, '.raider/flows'))
      File.symlink(target, File.join(dir, '.raider/flows/env'))

      output, = run_flow('ok')

      expect(output).to include('ignored .raider/flows/env: it must be a regular file you own', 'secret loaded=false')
    end

    it 'does not override a variable already set' do
      write_env_file("RAIDER_SECRET_TOKEN=hunter2\n", 0o600)

      output, = run_flow('ok', 'RAIDER_SECRET_TOKEN' => 'from-shell')

      expect(output).to include('secret loaded=false')
    end

    it 'keeps secret values out of the failed step title' do
      write_env_file("RAIDER_SECRET_TOKEN=hunter2\n", 0o600)

      run_flow('leaky')

      expect(log('leaky').last['failed_step']['title']).to eq('types [secret] somewhere')
      expect(File.read(File.join(dir, '.raider/flows/leaky/runs.jsonl'))).not_to include('hunter2')
    end
  end

  it 'keeps the last 50 log lines and the last 20 results folders, and only stamp-named folders' do
    FileUtils.mkdir_p(File.join(dir, '.raider/flows/ok'))
    File.write(File.join(dir, '.raider/flows/ok/runs.jsonl'), Array.new(60) { |i| "#{JSON.generate('n' => i)}\n" }.join)
    old = Array.new(25) { |i| format('flow-results/ok/20200101T0000%02dZ', i) }
    (old + ['flow-results/ok/keep-me']).each { |folder| FileUtils.mkdir_p(File.join(dir, folder)) }

    run_flow('ok')

    lines = log('ok')
    stamped = Dir.children(File.join(dir, 'flow-results/ok')).grep(/\A\d{8}T/)
    expect([lines.size, lines.first['n'], lines.last['status']]).to eq([50, 11, 'completed'])
    expect(stamped.size).to eq(20)
    expect(stamped).to include(File.basename(lines.last['results_dir']))
    expect(File).to be_directory(File.join(dir, 'flow-results/ok/keep-me'))
  end
end
