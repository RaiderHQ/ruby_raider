# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/schedules/schedule'
require_relative '../../../lib/utilities/schedules/os/launchd'
require_relative '../../../lib/utilities/schedules/os/task_scheduler'
require_relative '../../../lib/utilities/schedules/os/systemd'
require_relative '../../../lib/utilities/schedules/os/cron'

# The OS entry of a test schedule holds its name only: the selection, retries, notify and show_browser
# are read from schedules.yml at run time, so no file name or tag can reach a plist, XML, unit or crontab.
RSpec.describe 'A test schedule OS entry' do
  let(:tmp) { File.realpath(Dir.mktmpdir('schedules-entry')) }
  let(:root) { File.join(tmp, 'project') }
  let(:runner) { instance_double(RubyRaider::Schedules::Os::CommandRunner) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }
  let(:hostile) { %q(spec/$(id) & <x> "q" 'p' %PATH% `w`; rm -rf ~_spec.rb) }

  before do
    FileUtils.mkdir_p(File.join(root, 'spec'))
    [hostile, 'spec/a_spec.rb'].each { |file| File.write(File.join(root, file), '') }
  end

  after { FileUtils.rm_rf(tmp) }

  def schedule(**options)
    project = RubyRaider::Schedules::Project.new(root)
    RubyRaider::Schedules::Schedule.build(project: project, name: 'nightly', every: 'weekday', at: '07:30', now: now, host_os: 'darwin24', **options)
  end

  def kind = RubyRaider::Schedules::Kind::TESTS

  def entries(item)
    clock = Struct.new(:now).new(Time.new(2026, 11, 9, 10, 30, 0))
    systemd = RubyRaider::Schedules::Os::Systemd.new(kind: kind, runner: runner, home: tmp, config_home: nil)
    [RubyRaider::Schedules::Os::Launchd.new(kind: kind, runner: runner, home: tmp, uid: 501).plist(item),
     RubyRaider::Schedules::Os::TaskScheduler.new(kind: kind, runner: runner, clock: clock, schtasks: 'C:\\schtasks.exe').task_xml(item),
     systemd.service(item), systemd.timer(item), RubyRaider::Schedules::Os::Cron.new(kind: kind, runner: runner).line(item)]
  end

  it 'is byte-identical for two different selections, retries, notify and show_browser' do
    files = RubyRaider::Schedules::Selection.parse(files: [hostile, 'spec/a_spec.rb'], tag: nil, root: root, host_os: 'darwin24')
    all_tests = entries(schedule)
    picked = entries(schedule(selection: files, retries: 3, notify: true, show_browser: true))
    tagged = entries(schedule(selection: RubyRaider::Schedules::Selection.parse(files: [], tag: 'zz_tag_sentinel', root: root, host_os: 'darwin24')))

    expect([picked, tagged]).to eq([all_tests, all_tests])
    expect(all_tests.join).not_to include('rm -rf', '%PATH%', 'a_spec.rb', 'zz_tag_sentinel', '--retries', '--notify', 'show-browser', 'show_browser')
  end

  it 'names the test schedule kind and the schedule in every entry' do
    expect(entries(schedule)).to all(include('nightly', 'schedule'))
  end
end
