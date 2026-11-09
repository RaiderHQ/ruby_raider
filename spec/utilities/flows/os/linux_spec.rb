# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../../lib/utilities/flows/os/linux'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Flows::Os::Linux do # rubocop:disable RSpec/FilePath
  # Plays systemctl --user and crontab: answers keyed by "systemctl verb" or "crontab -l"; never runs anything
  let(:fake_runner_class) do
    Class.new do
      attr_reader :calls, :answers
      attr_accessor :table

      def initialize
        @calls = []
        @answers = {}
        @table = nil
      end

      def call(*argv, stdin_data: nil)
        @calls << argv
        key = argv.first == 'crontab' ? "crontab #{argv[1]}" : "systemctl #{argv[2]}"
        missing = key == 'crontab -l' && table.nil?
        stderr, status = answers.fetch(key) { missing ? ['no crontab for raider', 1] : ['', 0] }
        self.table = stdin_data if key == 'crontab -' && status.zero?
        RubyRaider::Flows::Os::CommandRunner::Result.new(stdout: key == 'crontab -l' ? table.to_s : '', stderr: stderr, exitstatus: status)
      end
    end
  end

  let(:tmp) { File.realpath(Dir.mktmpdir('flows-linux')) }
  let(:runner) { fake_runner_class.new }
  let(:item) do
    project = RubyRaider::Flows::Project.new(tmp)
    RubyRaider::Flows::Schedule.build(project: project, name: 'report', every: 'day', at: '08:00', now: Time.utc(2026, 11, 9))
  end
  let(:cron_block) { "# raider-flow #{item.os_id}\n#{RubyRaider::Flows::Os::Cron.new.line(item)}\n" }
  let(:no_bus) { ['Failed to connect to bus', 1] }

  # The systemd units go to a temp home, never the real one
  def pick = described_class.new(runner: runner, systemd: RubyRaider::Flows::Os::Systemd.new(runner: runner, home: tmp, config_home: nil))

  after { FileUtils.rm_rf(tmp) }

  it 'uses systemd when the user manager answers' do
    linux = pick

    expect([linux.label, linux.missed_runs_note, described_class.pick(runner).label]).to eq(['systemd', nil, 'systemd'])
    expect(runner.calls.uniq).to eq([%w[systemctl --user show-environment]])
  end

  it 'falls back to cron when it does not, or systemctl is missing' do
    [no_bus, ['Could not run systemctl', RubyRaider::Flows::Os::CommandRunner::MISSING]].each do |answer|
      runner.answers['systemctl show-environment'] = answer

      expect([pick.label, pick.missed_runs_note]).to eq(['cron', '(cron: missed runs are skipped)'])
    end
  end

  it 'installs with the primary scheduler only' do
    runner.answers['systemctl show-environment'] = no_bus

    pick.install(item)

    expect([runner.table, runner.calls.map(&:first).uniq]).to eq([cron_block, %w[systemctl crontab]])
  end

  describe '#remove' do
    it 'also removes a cron entry when systemd is the primary' do
      runner.table = "#{cron_block}1 * * * * a\n"

      expect(pick.remove(item.os_id)).to be(true)
      expect(runner.table).to eq("1 * * * * a\n")
    end

    it 'is false when neither has it' do
      expect(pick.remove(item.os_id)).to be(false)
    end

    it 'skips cron when crontab -l does not work' do
      runner.answers['crontab -l'] = ['crontab: not found', 127]

      expect(pick.remove(item.os_id)).to be(false)
      expect(runner.calls).not_to include(%w[crontab -])
    end

    it 'never asks systemd when cron is the primary, since systemd did not answer' do
      runner.answers['systemctl show-environment'] = no_bus
      runner.table = cron_block

      expect(pick.remove(item.os_id)).to be(true)
      expect(runner.calls.select { |argv| argv.first == 'systemctl' }).to eq([%w[systemctl --user show-environment]])
    end
  end

  describe 'with a systemd timer, from a session where systemd does not answer' do
    let(:units) { File.join(tmp, '.config', 'systemd', 'user') }

    before do
      runner.answers['systemctl show-environment'] = no_bus
      FileUtils.mkdir_p(units)
      File.write(File.join(units, "#{item.os_id}.timer"), 'x')
    end

    it 'is present' do
      expect(pick.present?(item.os_id)).to be(true)
    end

    it 'removes the cron block, then raises so the schedule is kept, and leaves the unit' do
      runner.table = "#{cron_block}1 * * * * a\n"

      expect { pick.remove(item.os_id) }
        .to raise_error(RubyRaider::Flows::Error, 'This schedule is a systemd timer; run raider flow unschedule report ' \
                                                  'from a session where systemctl --user works')
      expect([runner.table, File.exist?(File.join(units, "#{item.os_id}.timer"))]).to eq(["1 * * * * a\n", true])
    end
  end

  it 'does not look for systemd unit files when systemd is the primary' do
    FileUtils.mkdir_p(File.join(tmp, '.config', 'systemd', 'user'))
    File.write(File.join(tmp, '.config', 'systemd', 'user', "#{item.os_id}.timer"), 'x')

    expect(pick.remove(item.os_id)).to be(true)
  end

  describe '#present?' do
    it 'is true when only the other scheduler has it' do
      runner.answers['systemctl is-enabled'] = ['disabled', 1]
      runner.table = cron_block

      expect(pick.present?(item.os_id)).to be(true)
    end

    it 'is false when neither has it' do
      runner.answers['systemctl is-enabled'] = ['disabled', 1]

      expect(pick.present?(item.os_id)).to be(false)
    end

    it 'counts a failing other scheduler as not there' do
      runner.answers['systemctl is-enabled'] = ['disabled', 1]
      runner.answers['crontab -l'] = ['crontab: permission denied', 1]

      expect(pick.present?(item.os_id)).to be(false)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
