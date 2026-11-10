# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../../lib/utilities/schedules/adapter'
require_relative '../../../../lib/utilities/schedules/schedule'

# Every adapter's list_ids(prefix): the os_ids of one project's schedules of the adapter's Kind, found by
# enumerating the OS scheduler. Only a fake runner and a temp home: nothing real is read or run.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe 'Schedules adapters #list_ids' do
  # Answers each command from a table keyed by its first words; never runs anything
  let(:fake_runner_class) do
    Class.new do
      attr_reader :calls, :answers

      def initialize
        @calls = []
        @answers = {}
      end

      def call(*argv, stdin_data: nil)
        @calls << [argv, stdin_data]
        key = if argv.first.to_s.end_with?('schtasks.exe') then argv[1]
              elsif argv.first == 'systemctl' then argv.first(3).join(' ')
              else argv.first(2).join(' ')
              end
        stdout, status, stderr = answers.fetch(key, ['', 0, ''])
        RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: stdout, stderr: stderr.to_s, exitstatus: status)
      end
    end
  end

  let(:kind) { RubyRaider::Schedules::Kind::TESTS }
  let(:tmp) { File.realpath(Dir.mktmpdir('schedules-list-ids')) }
  let(:home) { File.join(tmp, 'home') }
  let(:runner) { fake_runner_class.new }
  let(:root) { File.join(tmp, 'project') }
  let(:prefix) { RubyRaider::Schedules::Schedule.os_id_prefix_for(root) }
  let(:other_prefix) { RubyRaider::Schedules::Schedule.os_id_prefix_for(File.join(tmp, 'other')) }
  let(:flow_prefix) { "#{RubyRaider::Schedules::Kind::FLOW_LEGACY.os_id_prefix}.#{prefix.split('.')[3]}." }
  let(:bad_utf8) { "#{prefix}a\xFF".dup.force_encoding(Encoding::UTF_8) }
  # What enumeration may see besides our two ids: another project, a flow schedule, a bad name, a longer
  # name, path tricks and bytes that are not UTF-8
  let(:noise) do
    ["#{other_prefix}nightly", "#{flow_prefix}nightly", "#{prefix}Bad", "#{prefix}#{'a' * 61}", "#{prefix}a.b", "#{prefix}..",
     "#{prefix}a b", prefix, "x#{prefix}nightly", bad_utf8]
  end

  let(:extra_children) { Hash.new { |hash, key| hash[key] = [] } }

  after { FileUtils.rm_rf(tmp) }

  # APFS refuses a file name that is not UTF-8, so those names are fed through Dir.children instead
  def touch(dir, *names)
    FileUtils.mkdir_p(dir)
    names.each { |name| name.valid_encoding? ? File.write(File.join(dir, name), '') : extra_children[dir] << name }
  end

  before do
    allow(Dir).to(receive(:children).and_wrap_original { |original, dir| original.call(dir) + extra_children[dir] })
  end

  it 'builds the prefix from the kind and the project path hash, ending in a dot' do
    expect(prefix).to match(/\Adev\.rubyraider\.schedule\.[0-9a-f]{10}\.\z/)
    expect(RubyRaider::Schedules::Schedule.os_id_for(root, 'nightly')).to eq("#{prefix}nightly")
  end

  describe RubyRaider::Schedules::Os::Launchd do
    let(:adapter) { described_class.new(kind: kind, runner: runner, home: home, uid: 501) }
    let(:agents) { File.join(home, 'Library', 'LaunchAgents') }

    it 'lists the plist basenames of this project and kind, sorted, and runs nothing' do
      touch(agents, "#{prefix}smoke.plist", "#{prefix}nightly.plist", "#{prefix}nightly.txt", ".#{prefix}x.plist.ab12.tmp",
            *noise.map { |id| "#{id}.plist" })

      expect(adapter.list_ids(prefix)).to eq(["#{prefix}nightly", "#{prefix}smoke"])
      expect([runner.calls, extra_children[agents]]).to eq([[], ["#{bad_utf8}.plist"]])
    end

    it 'is empty when there is no LaunchAgents folder' do
      expect(adapter.list_ids(prefix)).to eq([])
    end

    it 'raises an Error when the folder can not be read' do
      FileUtils.mkdir_p(File.join(home, 'Library'))
      File.write(agents, '')

      expect { adapter.list_ids(prefix) }.to raise_error(RubyRaider::Schedules::Error, /Could not read .*LaunchAgents/)
    end
  end

  describe RubyRaider::Schedules::Os::TaskScheduler do
    let(:adapter) { described_class.new(kind: kind, runner: runner, schtasks: 'C:\\Windows\\System32\\schtasks.exe') }

    def rows(*names) = names.map { |name| %("#{name}","11/10/2026 8:00:00 AM","Ready"\r\n) }.join

    it 'lists the tasks under \\RubyRaider\\ of this project and kind from one query' do
      listing = rows("\\RubyRaider\\#{prefix}smoke", "\\RubyRaider\\#{prefix}nightly", "\\Other\\#{prefix}elsewhere",
                     "\\RubyRaider\\sub\\#{prefix}deeper", "\\#{prefix}rootlevel", "\\RubyRaider\\#{prefix}smoke",
                     *noise.map { |id| "\\RubyRaider\\#{id}" })
      listing = "#{listing}garbage line\r\n\"unterminated\r\n"
      runner.answers['/Query'] = [listing.b, 0]

      expect(adapter.list_ids(prefix)).to eq(["#{prefix}nightly", "#{prefix}smoke"])
      expect(runner.calls.map(&:first)).to eq([['C:\\Windows\\System32\\schtasks.exe', '/Query', '/FO', 'CSV', '/NH']])
    end

    it 'raises an Error when the task list can not be read' do
      runner.answers['/Query'] = ['', 1, "ERROR: \e[2Jdenied"]

      expect { adapter.list_ids(prefix) }.to raise_error(RubyRaider::Schedules::Error, 'Task Scheduler could not list tasks: ERROR: ?[2Jdenied')
    end
  end

  describe RubyRaider::Schedules::Os::Systemd do
    let(:adapter) { described_class.new(kind: kind, runner: runner, home: home, config_home: nil) }
    let(:units) { File.join(home, '.config', 'systemd', 'user') }

    it 'lists the unit file names of this project and kind, without asking systemctl' do
      touch(units, "#{prefix}smoke.timer", "#{prefix}smoke.service", "#{prefix}nightly.service", "#{prefix}other.socket",
            ".#{prefix}x.timer.ab12.tmp", *noise.map { |id| "#{id}.timer" })

      expect(adapter.list_ids(prefix)).to eq(["#{prefix}nightly", "#{prefix}smoke"])
      expect(runner.calls).to be_empty
    end

    it 'reads the units folder under XDG_CONFIG_HOME when that is absolute' do
      config = File.join(tmp, 'xdg')
      touch(File.join(config, 'systemd', 'user'), "#{prefix}smoke.timer")

      expect(described_class.new(kind: kind, runner: runner, home: home, config_home: config).list_ids(prefix)).to eq(["#{prefix}smoke"])
    end

    it 'is empty when there is no units folder' do
      expect(adapter.list_ids(prefix)).to eq([])
    end
  end

  describe RubyRaider::Schedules::Os::Cron do
    let(:adapter) { described_class.new(kind: kind, runner: runner) }

    it 'lists the ids on our tag lines only, keeping the crontab as it is' do
      table = "MAILTO=x\n# raider-schedule #{prefix}smoke\n0 8 * * * cd /p && run\n# raider-schedule #{prefix}nightly\r\n" \
              "#  raider-schedule #{prefix}spaced\n# raider-schedule #{prefix}trailing \n" \
              "0 1 * * * echo '# raider-schedule #{prefix}inline'\n" \
              "#{noise.map { |id| "# raider-schedule #{id}\n" }.join}# raider-flow #{flow_prefix}legacy\n"
      runner.answers['crontab -l'] = [table.b, 0]

      expect(adapter.list_ids(prefix)).to eq(["#{prefix}nightly", "#{prefix}smoke"])
      expect(runner.calls.map(&:first)).to eq([%w[crontab -l]])
    end

    it 'is empty with no crontab, and raises an Error when crontab -l fails otherwise' do
      runner.answers['crontab -l'] = ['', 1, 'no crontab for raider']
      expect(adapter.list_ids(prefix)).to eq([])

      runner.answers['crontab -l'] = ['', 1, 'permission denied']
      expect { adapter.list_ids(prefix) }.to raise_error(RubyRaider::Schedules::Error, /could not read the crontab/)
    end
  end

  describe RubyRaider::Schedules::Os::Linux do
    let(:systemd) { RubyRaider::Schedules::Os::Systemd.new(kind: kind, runner: runner, home: home, config_home: nil) }
    let(:cron) { RubyRaider::Schedules::Os::Cron.new(kind: kind, runner: runner) }
    let(:units) { File.join(home, '.config', 'systemd', 'user') }

    before do
      touch(units, "#{prefix}timer_one.timer")
      runner.answers['crontab -l'] = ["# raider-schedule #{prefix}cron_one\n", 0]
    end

    it 'with systemd answering: the unit files plus the cron tags' do
      adapter = described_class.new(kind: kind, runner: runner, systemd: systemd, cron: cron)

      expect(adapter.list_ids(prefix)).to eq(["#{prefix}cron_one", "#{prefix}timer_one"])
    end

    it 'with no user bus: the cron tags plus the stranded unit files' do
      runner.answers['systemctl --user show-environment'] = ['', 1, 'Failed to connect to bus']
      adapter = described_class.new(kind: kind, runner: runner, systemd: systemd, cron: cron)

      expect(adapter.list_ids(prefix)).to eq(["#{prefix}cron_one", "#{prefix}timer_one"])
    end

    it 'leaves out the other scheduler when it fails, and raises when the primary one does' do
      runner.answers['crontab -l'] = ['', 1, 'permission denied']
      with_systemd = described_class.new(kind: kind, runner: runner, systemd: systemd, cron: cron)
      expect(with_systemd.list_ids(prefix)).to eq(["#{prefix}timer_one"])

      runner.answers['systemctl --user show-environment'] = ['', 1, 'Failed to connect to bus']
      with_cron = described_class.new(kind: kind, runner: runner, systemd: systemd, cron: cron)
      expect { with_cron.list_ids(prefix) }.to raise_error(RubyRaider::Schedules::Error, /could not read the crontab/)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
