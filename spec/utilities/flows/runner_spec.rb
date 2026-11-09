# frozen_string_literal: true

require 'json'
require 'stringio'
require 'tmpdir'
require_relative '../../../lib/utilities/flows/runner'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# The fake spawner needs its call, sleep and outcome lists next to the project and runner
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Flows::Runner do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('flows-runner')) }
  let(:project) { RubyRaider::Flows::Project.new(dir) }
  let(:out) { StringIO.new }
  let(:calls) { [] }
  let(:sleeps) { [] }
  let(:outcomes) { [] }

  # Stands in for `bundle exec rspec`: records the call and appends the line flows/support/run.rb would
  let(:spawner) do
    lambda do |env, argv, chdir|
      calls << { env: env, argv: argv, chdir: chdir }
      line = outcomes.shift || {}
      unless line == :nothing
        log = File.join(dir, '.raider/flows/report/runs.jsonl')
        FileUtils.mkdir_p(File.dirname(log))
        File.write(log, "#{JSON.generate(line_for(env, line))}\n", mode: 'a')
      end
      line == :nothing ? 2 : line.fetch(:code, 0)
    end
  end

  let(:runner) { described_class.new(project, out: out, spawner: spawner, sleeper: ->(seconds) { sleeps << seconds }) }

  def line_for(env, line)
    { 'started_at' => '2026-11-09T08:00:00.000Z', 'finished_at' => '2026-11-09T08:00:12.300Z', 'status' => 'completed',
      'attempt' => env['RAIDER_FLOW_ATTEMPT'].to_i, 'trigger' => env['RAIDER_FLOW_TRIGGER'],
      'run_id' => env['RAIDER_FLOW_RUN_ID'], 'results_dir' => 'flow-results/report/20261109T080000Z' }
      .merge(line.except(:code).transform_keys(&:to_s))
  end

  def log_statuses = File.readlines(File.join(dir, '.raider/flows/report/runs.jsonl')).map { |l| JSON.parse(l)['status'] }

  before do
    %w[flows/flow_helper.rb flows/support/run.rb flows/report_flow.rb].each do |file|
      FileUtils.mkdir_p(File.dirname(File.join(dir, file)))
      File.write(File.join(dir, file), '')
    end
    FileUtils.mkdir_p(File.join(dir, 'flow-results/report/20261109T080000Z'))
  end

  after { FileUtils.rm_rf(dir) }

  it 'runs the flow file through bundle exec rspec as an argv array, from the project root' do
    runner.run('report')

    expect(calls.first[:argv]).to eq(['bundle', 'exec', 'rspec', 'flows/report_flow.rb', '--tag', 'flow'])
    expect(calls.first[:chdir]).to eq(dir)
  end

  it 'exits 0 and prints the time and results folder when the flow completed' do
    expect(runner.run('report')).to eq(0)
    expect(out.string).to eq("Flow report completed in 12.3 s\nResults: flow-results/report/20261109T080000Z\n")
  end

  it 'exits 1 and names the step when a step failed' do
    outcomes << { status: 'failed', code: 1, failed_step: { 'number' => 4, 'title' => 'click "Export"', 'line' => 9 } }

    expect(runner.run('report')).to eq(1)
    expect(out.string).to start_with(%(Flow report failed at step 4 (click "Export")\n))
  end

  it 'names the line when the flow has no recorded steps' do
    outcomes << { status: 'failed', code: 1, failed_step: { 'title' => 'exports', 'line' => 9 } }

    runner.run('report')

    expect(out.string).to start_with("Flow report failed at line 9 (exports)\n")
  end

  it 'exits 2 on a setup error' do
    outcomes << { status: 'setup_error', code: 1 }

    expect(runner.run('report')).to eq(2)
    expect(out.string).to start_with("Flow report could not start: see the output above\n")
  end

  it 'exits 2 when the run left no log line' do
    outcomes << :nothing

    expect(runner.run('report')).to eq(2)
    expect(out.string).to eq("Flow report did not record a run (exit 2): see the output above\n")
  end

  it 'exits 3 without retrying when the flow is already running' do
    outcomes << { status: 'busy', code: 3, results_dir: nil }

    expect(runner.run('report', retries: 2)).to eq(3)
    expect([calls.size, sleeps]).to eq([1, []])
    expect(out.string).to eq("Flow report is already running\n")
  end

  it 'retries the whole flow 30 s later and exits 0 once it completes' do
    outcomes.push({ status: 'failed', code: 1 }, { status: 'completed' })

    expect(runner.run('report', retries: 2)).to eq(0)
    expect(sleeps).to eq([30])
    expect(calls.map { |call| call[:env]['RAIDER_FLOW_ATTEMPT'] }).to eq(%w[1 2])
    expect(log_statuses).to eq(%w[failed completed])
    expect(out.string).to include('Retrying in 30 s (attempt 2 of 3)')
  end

  it 'gives up after the last retry with the last status' do
    outcomes.push({ status: 'failed', code: 1 }, { status: 'setup_error', code: 1 })

    expect(runner.run('report', retries: 1)).to eq(2)
    expect(calls.size).to eq(2)
  end

  it 'reads each attempt by its own run id, not the last line in the log' do
    outcomes << { status: 'completed', run_id: 'someone-else' }

    expect(runner.run('report')).to eq(2)
  end

  it 'passes inputs, trigger and headless through the environment' do
    runner.run('report', inputs: ['who=ada lovelace', 'note=a=b'], trigger: 'schedule')
    env = calls.first[:env]

    expect(env).to include('RAIDER_FLOW_NAME' => 'report', 'RAIDER_FLOW_TRIGGER' => 'schedule', 'RAIDER_FLOW_HEADED' => nil,
                           'HEADLESS' => 'true', 'RETRY_COUNT' => '0',
                           'RAIDER_INPUT_WHO' => 'ada lovelace', 'RAIDER_INPUT_NOTE' => 'a=b')
    expect(env['RAIDER_FLOW_RUN_ID']).to match(/\A[0-9a-f]{16}\z/)
    expect(calls.first[:argv].join(' ')).not_to include('ada')
  end

  it 'unsets HEADLESS and sets RAIDER_FLOW_HEADED for --headed' do
    runner.run('report', headed: true)

    expect(calls.first[:env]).to include('RAIDER_FLOW_HEADED' => '1', 'HEADLESS' => nil)
  end

  describe 'refusals (exit 2 through Flows::Error, nothing spawned)' do
    def refuse(name, message, **options)
      expect { runner.run(name, **options) }.to raise_error(RubyRaider::Flows::Error, message)
      expect(calls).to be_empty
    end

    it('rejects an input name that is not lower snake case') { refuse('report', /Invalid input "WHO"/, inputs: ['WHO=x']) }
    it('rejects an input without a value') { refuse('report', /Invalid input "who"/, inputs: ['who']) }
    it('rejects retries above 3') { refuse('report', /Invalid retries 4/, retries: 4) }
    it('rejects an unknown trigger') { refuse('report', /Invalid trigger/, trigger: 'cron') }
    it('rejects an unsafe flow name') { refuse('../report', /Invalid flow name/) }

    it 'rejects a project without flow init' do
      File.delete(File.join(dir, 'flows/support/run.rb'))

      refuse('report', /run raider flow init/)
    end
  end

  describe '.spawn' do
    it 'runs without a shell and returns the exit status' do
      code = described_class.spawn({ 'X' => '; exit 7' }, [RbConfig.ruby, '-e', 'exit(ENV["X"] == "; exit 7" ? 5 : 6)'], dir)

      expect(code).to eq(5)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
