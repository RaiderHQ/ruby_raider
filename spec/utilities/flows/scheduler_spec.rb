# frozen_string_literal: true

require 'json'
require 'stringio'
require 'tmpdir'
require_relative '../../../lib/utilities/flows/scheduler'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# The fake adapter, store and streams sit next to the project and scheduler
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Flows::Scheduler do # rubocop:disable RSpec/FilePath
  # Stands in for an OS scheduler: records every call, keeps the installed os_ids
  let(:fake_adapter) do
    Class.new do
      attr_reader :calls, :installed
      attr_accessor :fail_present

      def initialize
        @calls = []
        @installed = []
      end

      def label = 'fakeos'

      def install(schedule)
        @calls << [:install, schedule.os_id]
        @installed |= [schedule.os_id]
        true
      end

      def remove(os_id)
        @calls << [:remove, os_id]
        !@installed.delete(os_id).nil?
      end

      def present?(os_id)
        raise RubyRaider::Flows::Error, 'task list unreadable' if fail_present

        @installed.include?(os_id)
      end
    end
  end

  let(:dir) { File.realpath(Dir.mktmpdir('flows-scheduler')) }
  let(:project) { RubyRaider::Flows::Project.new(dir) }
  let(:adapter) { fake_adapter.new }
  let(:store) { RubyRaider::Flows::ScheduleStore.new(project) }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  # Sun 8 Nov 2026 12:00 local
  let(:now) { Time.local(2026, 11, 8, 12, 0) }
  let(:scheduler) { described_class.new(project, adapter: adapter, store: store, out: out, err: err, now: -> { now }) }
  let(:os_id) { RubyRaider::Flows::Schedule.os_id_for(dir, 'report') }

  before do
    %w[flows/flow_helper.rb flows/support/run.rb flows/report_flow.rb].each do |file|
      FileUtils.mkdir_p(File.dirname(File.join(dir, file)))
      File.write(File.join(dir, file), '')
    end
  end

  after { FileUtils.rm_rf(dir) }

  def log_run(name, line)
    file = File.join(dir, ".raider/flows/#{name}/runs.jsonl")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, "#{JSON.generate(line)}\n", mode: 'a')
  end

  describe '.adapter' do
    let(:runner) { instance_double(RubyRaider::Schedules::Os::CommandRunner) }

    def result(success)
      RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: '', stderr: '', exitstatus: success ? 0 : 1)
    end

    it 'picks launchd on macOS and Task Scheduler on Windows without calling them' do
      picked = %w[darwin25 mingw32 mswin64 cygwin].map { |host| described_class.adapter(runner: runner, host_os: host).class }

      expect(picked).to eq([RubyRaider::Schedules::Os::Launchd] + ([RubyRaider::Schedules::Os::TaskScheduler] * 3))
    end

    it 'picks the Linux adapter, which labels itself by the scheduler that answers' do
      allow(runner).to receive(:call).and_return(result(true), result(false))

      picked = 2.times.map { described_class.adapter(runner: runner, host_os: 'linux-gnu') }

      expect(picked.map { |adapter| [adapter.class, adapter.label] })
        .to eq([[RubyRaider::Schedules::Os::Linux, 'systemd'], [RubyRaider::Schedules::Os::Linux, 'cron']])
    end

    it 'refuses another OS' do
      expect { described_class.adapter(runner: runner, host_os: 'solaris2') }
        .to raise_error(RubyRaider::Flows::Error, 'Scheduling flows is not supported on solaris2')
    end
  end

  describe '#schedule' do
    it 'installs the OS entry, then writes the yml, and says when it next runs' do
      allow(store).to receive(:save).and_wrap_original do |original, schedule|
        expect(adapter.installed).to include(schedule.os_id)
        original.call(schedule)
      end

      scheduler.schedule('report', every: 'weekday', at: '08:00')

      expect(out.string).to eq("Scheduled report: every weekday at 08:00. Next run Mon 9 Nov 08:00.\n")
      expect([adapter.calls, store.find('report').rule_text]).to eq([[[:install, os_id]], 'every weekday at 08:00'])
    end

    it 'stores notify and adds --notify to the OS entry' do
      allow(adapter).to receive(:install).and_wrap_original do |original, schedule|
        expect(schedule.argv).to include('--notify')
        original.call(schedule)
      end
      scheduler.schedule('report', every: 'day', at: '08:00', notify: true)

      expect([store.find('report').notify, out.string]).to eq([true, "Scheduled report: every day at 08:00 (notify). Next run Mon 9 Nov 08:00.\n"])
    end

    it 'says Replaced when the flow already had a schedule' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      scheduler.schedule('report', every: 'week', at: '09:30', on: 'wed')

      expect(out.string.lines.last).to eq("Replaced the schedule for report: every week on wed at 09:30. Next run Wed 11 Nov 09:30.\n")
      expect(store.all.map(&:rule_text)).to eq(['every week on wed at 09:30'])
    end

    it 'removes the OS entry again when the yml cannot be written' do
      allow(store).to receive(:save).and_raise(RubyRaider::Flows::Error, 'disk full')

      expect { scheduler.schedule('report', every: 'day', at: '08:00') }
        .to raise_error(RubyRaider::Flows::Error, 'disk full: the fakeos entry was removed too, so report is not scheduled')
      expect([adapter.calls, adapter.installed]).to eq([[[:install, os_id], [:remove, os_id]], []])
    end

    it 'needs the flow file and flows set up, and checks the rule, before touching the OS' do
      expect { scheduler.schedule('nope', every: 'day', at: '08:00') }.to raise_error(RubyRaider::Flows::Error, /No flow nope/)
      expect { scheduler.schedule('report', every: 'day') }.to raise_error(RubyRaider::Flows::Error, /needs at/)
      File.delete(File.join(dir, 'flows/support/run.rb'))
      expect { scheduler.schedule('report', every: 'day', at: '08:00') }
        .to raise_error(RubyRaider::Flows::Error, 'Flows are not set up in this project: run raider flow init')
      expect(adapter.calls).to be_empty
    end

    it 'checks schedules.yml can be written before installing the OS entry' do
      FileUtils.mkdir_p(File.join(dir, '.raider/flows'))
      File.write(File.join(dir, '.raider/flows/schedules.yml'), "schedules: [\n")

      expect { scheduler.schedule('report', every: 'day', at: '08:00') }
        .to raise_error(RubyRaider::Flows::Error, /schedules.yml is not a schedules file/)
      expect(adapter.calls).to be_empty
    end

    it 'refuses with a Flows::Error when the flow folder cannot be made' do
      File.write(File.join(dir, '.raider'), '')

      expect { scheduler.schedule('report', every: 'day', at: '08:00') }
        .to raise_error(RubyRaider::Flows::Error, %r{\ACould not make \.raider/flows: })
      expect(adapter.calls).to be_empty
    end

    it 'makes .raider/flows/<name> a 0700 folder and refuses a link there' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      expect(File.stat(File.join(dir, '.raider/flows/report')).mode & 0o777).to eq(0o700)

      FileUtils.rm_rf(File.join(dir, '.raider/flows/report'))
      File.symlink(FileUtils.mkdir_p(File.join(dir, 'elsewhere')).first, File.join(dir, '.raider/flows/report'))
      expect { scheduler.schedule('report', every: 'day', at: '08:00') }
        .to raise_error(RubyRaider::Flows::Error, '.raider/flows/report must be a folder, not a link')
      expect(adapter.calls).to eq([[:install, os_id]])
    end
  end

  describe '#unschedule' do
    it 'keeps the yml entry when the OS scheduler refuses the removal' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      allow(adapter).to receive(:remove).and_raise(RubyRaider::Flows::Error, 'systemd units found')

      expect { scheduler.unschedule('report') }.to raise_error(RubyRaider::Flows::Error, 'systemd units found')
      expect(store.find('report')).not_to be_nil
    end

    it 'removes the yml entry and the OS entry' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      scheduler.unschedule('report')

      expect([out.string.lines.last, store.all, adapter.installed]).to eq(["Unscheduled report\n", [], []])
    end

    it 'says when the OS entry was already gone' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      adapter.installed.clear
      scheduler.unschedule('report')

      expect([out.string.lines.last, store.all]).to eq(["Unscheduled report (it was already gone from fakeos)\n", []])
    end

    it 'removes an OS entry with no yml entry, even for a deleted flow' do
      adapter.installed << RubyRaider::Flows::Schedule.os_id_for(dir, 'gone')
      scheduler.unschedule('gone')

      expect([out.string, adapter.installed]).to eq(["Unscheduled gone\n", []])
    end

    it 'refuses a flow with no schedule anywhere, and an invalid name' do
      expect { scheduler.unschedule('report') }.to raise_error(RubyRaider::Flows::Error, 'No schedule for report')
      expect { scheduler.unschedule('Bad-Name') }.to raise_error(RubyRaider::Flows::Error, /Invalid flow name/)
    end

    it 'says the OS entry was already removed when schedules.yml can not be written' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      allow(store).to receive(:delete).and_raise(Errno::EACCES, 'schedules.yml')

      expect { scheduler.unschedule('report') }.to raise_error(RubyRaider::Flows::Error) do |error|
        expect([error.message, error.exit_code]).to eq(
          ['Permission denied - schedules.yml: the fakeos entry was already removed, but schedules.yml still lists report', 2]
        )
      end
      expect(adapter.installed).to eq([])
    end

    it 'warns that an OS entry from another project path may remain when the yml entry was unreadable' do
      FileUtils.mkdir_p(File.join(dir, '.raider/flows'))
      File.write(File.join(dir, '.raider/flows/schedules.yml'), { 'schedules' => [{ 'name' => 'report' }] }.to_yaml)
      scheduler.unschedule('report')

      expect(out.string).to eq("Unscheduled report (it was already gone from fakeos)\n")
      expect(err.string).to include('could not be read', 'fakeos entry made from a different project path may remain')
    end
  end

  describe '#schedules' do
    it 'lists each schedule with its rule, next run, last result and OS state' do
      scheduler.schedule('report', every: 'hour', at: ':15', retries: 2, inputs: ['who=me'], notify: true)
      log_run('report', 'status' => 'failed', 'finished_at' => "2026-11-09T08:00:12Z\e[2J", 'trigger' => 'schedule',
                        'failed_step' => 'Open', 'results_dir' => 'flow-results/report/x', 'run_id' => 'abc')
      out.truncate(0)
      out.rewind
      scheduler.schedules

      expect(out.string).to eq("#{'report'.ljust(30)}  every hour at :15 (notify)  next Sun 8 Nov 12:15  failed  2026-11-09T08:00:12Z?[2J  ok\n")
    end

    it 'fails the text list when the OS scheduler cannot be asked, as in 4.1' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      allow(described_class).to receive(:adapter).and_raise(RubyRaider::Flows::Error, 'Scheduling flows is not supported on solaris2')
      lister = described_class.new(project, store: store, out: out, err: err, now: -> { now })

      expect { lister.schedules }.to raise_error(RubyRaider::Flows::Error, 'Scheduling flows is not supported on solaris2')
    end

    it 'prints the JSON the desktop app reads' do
      scheduler.schedule('report', every: 'week', at: '08:00', on: 'mon', inputs: ['who=me'], notify: true)
      log_run('report', 'status' => 'completed', 'finished_at' => 'f', 'trigger' => 't', 'failed_step' => nil, 'results_dir' => 'r', 'run_id' => 'x')
      out.truncate(0)
      out.rewind
      scheduler.schedules(json: true)

      expect(JSON.parse(out.string)).to eq(
        [{ 'name' => 'report', 'every' => 'week', 'at' => '08:00', 'on' => 'mon', 'retries' => 0, 'inputs' => ['who=me'], 'notify' => true,
           'next_run_at' => Time.local(2026, 11, 9, 8, 0).iso8601, 'os_state' => 'ok',
           'last' => { 'status' => 'completed', 'finished_at' => 'f', 'trigger' => 't', 'failed_step' => nil, 'results_dir' => 'r' } }]
      )
    end

    it 'says Ruby not found when the stored ruby is gone, and missing when the OS entry is gone' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      FileUtils.touch(File.join(dir, 'flows/other_flow.rb'))
      fields = store.find('report').to_h.transform_keys(&:to_sym)
      other = { name: 'other', os_id: RubyRaider::Flows::Schedule.os_id_for(dir, 'other'), ruby: '/nonexistent/ruby' }
      store.save(RubyRaider::Flows::Schedule.new(**fields, **other, project_root: dir))
      adapter.installed.clear
      out.truncate(0)
      out.rewind
      scheduler.schedules(json: true)

      expect(JSON.parse(out.string).map { |row| [row['name'], row['os_state'], row['last']] })
        .to eq([['other', 'Ruby not found: re-schedule', nil], ['report', 'missing from fakeos', nil]])
    end

    it 'says flow not found when the flow file is gone, after Ruby not found and before the OS state' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      FileUtils.touch(File.join(dir, 'flows/other_flow.rb'))
      fields = store.find('report').to_h.transform_keys(&:to_sym)
      other = { name: 'other', os_id: RubyRaider::Flows::Schedule.os_id_for(dir, 'other'), ruby: '/nonexistent/ruby' }
      store.save(RubyRaider::Flows::Schedule.new(**fields, **other, project_root: dir))
      %w[report other].each { |name| File.delete(File.join(dir, "flows/#{name}_flow.rb")) }
      adapter.fail_present = true
      scheduler.schedules(json: true)

      expect(JSON.parse(out.string.lines.last).map { |row| [row['name'], row['os_state']] })
        .to eq([['other', 'Ruby not found: re-schedule'], ['report', 'flow not found: unschedule']])
    end

    it 'adds a row for a flow the OS still schedules with no yml entry' do
      adapter.installed << os_id
      scheduler.schedules(json: true)

      expect(JSON.parse(out.string)).to eq(
        [{ 'name' => 'report', 'every' => nil, 'at' => nil, 'on' => nil, 'retries' => nil, 'inputs' => nil, 'notify' => nil,
           'next_run_at' => nil, 'os_state' => 'missing from schedules.yml', 'last' => nil }]
      )
    end

    it 'shows unknown when the OS state cannot be read' do
      scheduler.schedule('report', every: 'day', at: '08:00')
      adapter.fail_present = true
      out.truncate(0)
      out.rewind
      scheduler.schedules

      expect(out.string).to end_with("  never run  unknown (task list unreadable)\n")
    end

    it 'prints the missed runs note of an adapter that has one, once' do
      adapter.define_singleton_method(:missed_runs_note) { '(fakeos: missed runs are skipped)' }
      %w[report other].each do |name|
        FileUtils.touch(File.join(dir, "flows/#{name}_flow.rb"))
        scheduler.schedule(name, every: 'day', at: '08:00')
      end
      out.truncate(0)
      out.rewind
      scheduler.schedules

      expect(out.string.lines.size).to eq(3)
      expect(out.string.lines.last).to eq("(fakeos: missed runs are skipped)\n")
    end

    it 'says how to add one when there are none' do
      scheduler.schedules

      expect(out.string).to eq("No schedules yet: raider flow schedule <name> --every day --at 08:00\n")
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
