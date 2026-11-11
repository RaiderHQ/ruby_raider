# frozen_string_literal: true

require 'stringio'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/scheduler'

# The scheduler with the real launchd adapter: plists in a temp home, launchctl and plutil played by a fake
# runner. Nothing real is run and the real ~/Library/LaunchAgents is never read.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::Scheduler do # rubocop:disable RSpec/FilePath
  # Records every command and answers success; launchctl print succeeds only for a loaded service
  let(:runner_class) do
    Class.new do
      attr_reader :calls, :loaded

      def initialize
        @calls = []
        @loaded = []
      end

      def call(*argv, **)
        @calls << argv
        verb = argv[1]
        target = argv.last
        status = 0
        case verb
        when 'bootstrap' then @loaded << File.basename(target, '.plist')
        when 'bootout' then status = @loaded.delete(target.split('/').last) ? 0 : 3
        when 'print' then status = @loaded.include?(target.split('/').last) ? 0 : 113
        end
        RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: '', stderr: '', exitstatus: status)
      end
    end
  end

  let(:tmp) { File.realpath(Dir.mktmpdir('schedules-launchd-wiring')) }
  let(:home) { File.join(tmp, 'home') }
  let(:root) { File.join(tmp, 'project').tap { |dir| FileUtils.mkdir_p(dir) } }
  let(:project) { RubyRaider::Schedules::Project.new(root) }
  let(:runner) { runner_class.new }
  let(:launchd) { RubyRaider::Schedules::Os::Launchd.new(kind: RubyRaider::Schedules::Kind::TESTS, runner: runner, home: home, uid: 501) }
  let(:out) { StringIO.new }
  let(:scheduler) do
    described_class.new(project, adapter: launchd, out: out, err: StringIO.new, now: -> { Time.local(2026, 11, 8, 12) }, host_os: 'darwin25')
  end
  let(:os_id) { RubyRaider::Schedules::Schedule.os_id_for(project.root, 'nightly') }
  let(:plist) { File.join(home, 'Library', 'LaunchAgents', "#{os_id}.plist") }

  after { FileUtils.rm_rf(tmp) }

  def states
    out.truncate(0)
    out.rewind
    scheduler.list(json: true)
    JSON.parse(out.string)['schedules'].map { |row| [row['name'], row['os_state']] }
  end

  it 'adds, lists an entry schedules.yml lost, and removes it, touching only the temp home' do
    scheduler.add('nightly', every: 'day', at: '08:00')
    expect([File.file?(plist), states]).to eq([true, [%w[nightly ok]]])

    File.write(File.join(project.root, '.raider/schedules/schedules.yml'), "schedules: []\n")
    expect(states).to eq([['nightly', 'missing from schedules.yml']])

    scheduler.remove('nightly')
    expect([File.exist?(plist), states, out.string]).to eq([false, [], %({"notice":null,"schedules":[]}\n)])
    expect(runner.calls.flatten.select { |arg| arg.start_with?('/') && !arg.start_with?('/bin/', '/usr/bin/') }).to all(start_with(tmp))
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
