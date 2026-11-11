# frozen_string_literal: true

require 'stringio'
require 'tmpdir'
require 'yaml'
require_relative '../../../lib/utilities/schedules/legacy'
require_relative '../../../lib/utilities/schedules/project'

# Every adapter here is a recording double, or a real one on a command double and a temp home: nothing
# reaches launchctl, crontab, systemctl or the real ~/Library/LaunchAgents.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::Legacy do # rubocop:disable RSpec/FilePath
  # Answers list_ids from ids and remove from answers by name (true unless told: false, or an error to raise)
  let(:fake_adapter_class) do
    Class.new do
      attr_reader :calls, :answers
      attr_accessor :ids, :on_remove

      def initialize(ids = [])
        @calls = []
        @ids = ids
        @answers = {}
      end

      def list_ids(prefix)
        @calls << [:list_ids, prefix]
        ids.select { |id| id.start_with?(prefix) }
      end

      def remove(os_id)
        @calls << [:remove, os_id]
        on_remove&.call(os_id)
        answer = answers.fetch(os_id.split('.').last, true)
        raise answer if answer.is_a?(Exception)

        answer
      end
    end
  end

  # Plays launchctl, crontab and systemctl: records argv, keeps the crontab, answers from a table by verb
  let(:fake_runner_class) do
    Class.new do
      attr_reader :calls, :answers
      attr_accessor :table

      def initialize
        @calls = []
        @answers = {}
      end

      def call(*argv, stdin_data: nil)
        @calls << argv
        key = argv.first == '/bin/launchctl' ? argv[1] : argv.reject { |arg| arg == '--user' }.first(2).join(' ')
        stderr, status = answers.fetch(key) { key == 'crontab -l' && table.nil? ? ['no crontab for raider', 1] : ['', 0] }
        self.table = stdin_data if key == 'crontab -' && status.zero?
        RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: key == 'crontab -l' ? table.to_s : '', stderr: stderr, exitstatus: status)
      end
    end
  end

  let(:tmp) { File.realpath(Dir.mktmpdir('schedules-legacy')) }
  let(:home) { File.join(tmp, 'home') }
  let(:agents) { File.join(home, 'Library', 'LaunchAgents') }
  let(:a_dir) { project_dir('a') }
  let(:b_dir) { project_dir('b') }
  let(:err) { StringIO.new }
  let(:runner) { fake_runner_class.new }
  let(:kind) { RubyRaider::Schedules::Kind::FLOW_LEGACY }
  let(:old_rule) { described_class::OldRule }

  after { FileUtils.rm_rf(tmp) }

  def project_dir(name)
    dir = File.join(tmp, name)
    FileUtils.mkdir_p(dir)
    dir
  end

  def project(dir) = RubyRaider::Schedules::Project.new(dir)

  def os_id(dir, name) = old_rule.os_id_for(dir, name)

  def yml(dir) = File.join(dir, '.raider', 'flows', 'schedules.yml')

  # A 4.1 schedules.yml; each entry a name and its os_id for this project unless given
  def write_yml(dir, *names, entries: names.map { |name| { 'name' => name, 'every' => 'day', 'at' => '08:00', 'os_id' => os_id(dir, name) } })
    FileUtils.mkdir_p(File.dirname(yml(dir)))
    File.write(yml(dir), YAML.dump({ 'schedules' => entries }))
  end

  def cleanup(dir, adapter, **options) = described_class.new(project(dir), adapter: adapter, err: err).cleanup(**options)

  def removed(*names) = names.map { |name| [:remove, os_id(a_dir, name)] }

  def removed_notice(*names)
    one = names.size == 1
    "Removed #{one ? '1 schedule' : "#{names.size} schedules"} made with Ruby Raider 4.1 (#{names.join(', ')}); " \
      "#{one ? 'it' : 'they'} can't run in 4.2. Add #{one ? 'it' : 'them'} again with raider schedule add."
  end

  describe 'with launchd' do
    let(:launchd) { RubyRaider::Schedules::Os::Launchd.new(kind: kind, runner: runner, home: home, uid: 501) }

    def plist(dir, name) = File.join(agents, "#{os_id(dir, name)}.plist")

    def write_plist(path, text = 'x')
      FileUtils.mkdir_p(agents)
      File.write(path, text)
    end

    it "removes only this project's entry when another project has one with the same name" do
      write_yml(a_dir, 'report')
      write_plist(plist(a_dir, 'report'))
      write_plist(plist(b_dir, 'report'), "b's plist")

      notice = cleanup(a_dir, launchd)

      expect(notice).to eq(removed_notice('report'))
      expect(err.string).to eq("#{removed_notice('report')}\n")
      expect([File.exist?(plist(a_dir, 'report')), File.read(plist(b_dir, 'report')), File.exist?(yml(a_dir))]).to eq([false, "b's plist", false])
      expect(runner.calls).to eq([['/bin/launchctl', 'bootout', "gui/501/#{os_id(a_dir, 'report')}"]])
    end

    it 'never uses an os_id stored in the yml: an entry copied from elsewhere is skipped' do
      foreign = 'dev.rubyraider.flow.1255a248a3.tredssd'
      write_yml(a_dir, entries: [{ 'name' => 'tredssd', 'os_id' => foreign }])
      write_plist(File.join(agents, "#{foreign}.plist"), 'live')
      write_plist(plist(a_dir, 'tredssd'))

      notice = cleanup(a_dir, launchd)

      expect(notice).to eq(removed_notice('tredssd'))
      expect(runner.calls.flatten.grep(/1255a248a3/)).to be_empty
      expect(File.read(File.join(agents, "#{foreign}.plist"))).to eq('live')
    end
  end

  it 'never passes a stored os_id to remove' do
    write_yml(a_dir, entries: [{ 'name' => 'tredssd', 'os_id' => 'dev.rubyraider.flow.1255a248a3.tredssd' }])
    adapter = fake_adapter_class.new(['dev.rubyraider.flow.1255a248a3.tredssd'])

    expect(cleanup(a_dir, adapter)).to be_nil
    expect(adapter.calls.flatten.grep(/1255a248a3/)).to be_empty
  end

  describe 'with cron' do
    let(:cron) { RubyRaider::Schedules::Os::Cron.new(kind: kind, runner: runner) }

    def pair(dir, name)
      "# raider-flow #{os_id(dir, name)}\n" \
        "0 8 * * * cd #{dir} && /usr/bin/env /r /b exec raider flow run #{name} --project #{dir} --trigger schedule >> /l 2>&1\n"
    end

    it "removes only this project's tagged pair; every other byte stays" do
      runner.table = "#{pair(b_dir, 'report')}MAILTO=\"\"\n5 * * * * /usr/bin/backup  --keep\n#{pair(a_dir, 'report')}"

      expect(cleanup(a_dir, cron)).to eq(removed_notice('report'))
      expect(runner.table).to eq("#{pair(b_dir, 'report')}MAILTO=\"\"\n5 * * * * /usr/bin/backup  --keep\n")
    end
  end

  describe 'on Linux, cron with systemd unit files left behind' do
    let(:units) { File.join(home, '.config', 'systemd', 'user') }
    let(:linux) do
      systemd = RubyRaider::Schedules::Os::Systemd.new(kind: kind, runner: runner, home: home, config_home: nil)
      RubyRaider::Schedules::Os::Linux.new(kind: kind, runner: runner, systemd: systemd)
    end
    let(:stranded) do
      'Could not remove 1 schedule made with Ruby Raider 4.1 (report: This schedule is a systemd timer; run raider schedule list ' \
        'from a session where systemctl --user works); it is tried again next time.'
    end

    before do
      runner.answers['systemctl show-environment'] = ['Failed to connect to bus', 1]
      FileUtils.mkdir_p(units)
      File.write(File.join(units, "#{os_id(a_dir, 'report')}.timer"), 'x')
    end

    it 'reports the failure, keeps the yml, and tries again next time' do
      write_yml(a_dir, 'report')

      first = cleanup(a_dir, linux)
      FileUtils.rm_f(yml(a_dir))
      second = cleanup(a_dir, linux)

      expect([first, second]).to eq([stranded, stranded])
      expect(err.string.lines).to eq(["#{stranded}\n", "#{stranded}\n"])
      expect(File.exist?(File.join(units, "#{os_id(a_dir, 'report')}.timer"))).to be(true)
    end

    it 'keeps the yml' do
      write_yml(a_dir, 'report')
      cleanup(a_dir, linux)

      expect(File.exist?(yml(a_dir))).to be(true)
    end
  end

  describe 'a failed removal' do
    it 'keeps the yml; a later run deletes it and reports only what it removed then' do
      write_yml(a_dir, 'alpha', 'beta')
      adapter = fake_adapter_class.new
      adapter.answers['beta'] = RubyRaider::Schedules::Error.new("busy\nnow")

      first = cleanup(a_dir, adapter)
      kept = File.exist?(yml(a_dir))
      adapter.answers.replace('alpha' => false)
      second = cleanup(a_dir, adapter)

      expect(first).to eq("#{removed_notice('alpha')} Could not remove 1 schedule made with Ruby Raider 4.1 (beta: busy?now); it is tried again next time.")
      expect([kept, second, File.exist?(yml(a_dir))]).to eq([true, removed_notice('beta'), false])
      expect(err.string.lines.size).to eq(2)
    end

    it 'counts in the plural' do
      write_yml(a_dir, 'alpha', 'beta')
      adapter = fake_adapter_class.new
      adapter.answers.replace('alpha' => RubyRaider::Schedules::Error.new('x'), 'beta' => RubyRaider::Schedules::Error.new('y'))

      expect(cleanup(a_dir, adapter))
        .to eq('Could not remove 2 schedules made with Ruby Raider 4.1 (alpha: x, beta: y); they are tried again next time.')
    end

    it 'names every schedule it removed, from the yml and the OS, sorted' do
      write_yml(a_dir, 'beta')
      adapter = fake_adapter_class.new([os_id(a_dir, 'alpha'), os_id(a_dir, 'beta')])

      expect(cleanup(a_dir, adapter)).to eq(removed_notice('alpha', 'beta'))
      expect(adapter.calls.drop(1)).to eq(removed('alpha', 'beta'))
    end
  end

  describe 'with nothing to clean' do
    it 'is nil, prints nothing, creates or deletes nothing, and only enumerates' do
      adapter = fake_adapter_class.new
      FileUtils.mkdir_p(File.join(a_dir, 'flows'))
      before = Dir.glob('**/*', File::FNM_DOTMATCH, base: tmp).sort

      expect(cleanup(a_dir, adapter)).to be_nil
      expect([err.string, Dir.glob('**/*', File::FNM_DOTMATCH, base: tmp).sort]).to eq(['', before])
      expect(adapter.calls).to eq([[:list_ids, old_rule.os_id_prefix_for(a_dir)]])
    end

    it 'is nil when the entries are already gone, and deletes the yml' do
      write_yml(a_dir, 'report')
      adapter = fake_adapter_class.new
      adapter.answers['report'] = false

      expect([cleanup(a_dir, adapter), err.string, File.exist?(yml(a_dir))]).to eq([nil, '', false])
    end

    it 'does nothing where there is no OS scheduler' do
      write_yml(a_dir, 'report')
      allow(RubyRaider::Schedules).to receive(:adapter).and_raise(RubyRaider::Schedules::Error, 'Scheduling 4.1 schedules is not supported on solaris')

      expect([described_class.new(project(a_dir), err: err).cleanup, err.string, File.exist?(yml(a_dir))]).to eq([nil, '', true])
      expect(RubyRaider::Schedules).to have_received(:adapter).with(kind: kind)
    end
  end

  describe 'a yml it does not read' do
    let(:adapter) { fake_adapter_class.new }

    it 'skips .raider/flows when it is a link to another folder, and leaves what is there' do
      outside = project_dir('outside')
      write_yml(outside, entries: [{ 'name' => 'report', 'os_id' => os_id(a_dir, 'report') }])
      FileUtils.mkdir_p(File.join(a_dir, '.raider'))
      File.symlink(File.join(outside, '.raider', 'flows'), File.join(a_dir, '.raider', 'flows'))

      expect(cleanup(a_dir, adapter)).to be_nil
      expect([adapter.calls.map(&:first), File.exist?(yml(outside))]).to eq([[:list_ids], true])
    end

    it 'skips a schedules.yml that is a link, and leaves it' do
      outside = project_dir('outside')
      write_yml(outside, entries: [{ 'name' => 'report', 'os_id' => os_id(a_dir, 'report') }])
      FileUtils.mkdir_p(File.dirname(yml(a_dir)))
      File.symlink(yml(outside), yml(a_dir))

      expect(cleanup(a_dir, adapter)).to be_nil
      expect([adapter.calls.map(&:first), File.symlink?(yml(a_dir)), File.exist?(yml(outside))]).to eq([[:list_ids], true, true])
    end

    it 'skips entries that are not 4.1 ones, and a file that is too big or not YAML' do
      write_yml(a_dir, entries: [{ 'name' => 123, 'os_id' => os_id(a_dir, '123') }, { 'name' => 'env', 'os_id' => os_id(a_dir, 'env') },
                                 { 'name' => 'Caps', 'os_id' => os_id(a_dir, 'Caps') }, { 'name' => 'nameless' }, 'report'])
      results = [cleanup(a_dir, adapter)]
      ["schedules: [\n", "schedules:\n  - name: #{'a' * 1_000_001}\n"].each do |text|
        FileUtils.mkdir_p(File.dirname(yml(a_dir)))
        File.write(yml(a_dir), text)
        results << cleanup(a_dir, adapter)
      end

      expect(results).to eq([nil, nil, nil])
      expect(adapter.calls.map(&:first).uniq).to eq([:list_ids])
    end
  end

  it "leaves the user's files" do
    write_yml(a_dir, 'report')
    kept = %w[flows/login.yml flow-results/run.json .raider/flows/env .raider/flows/report/scheduler.log .raider/tests/flows/x.rb]
    kept.each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(a_dir, path)))
      File.write(File.join(a_dir, path), path)
    end

    expect(cleanup(a_dir, fake_adapter_class.new)).to eq(removed_notice('report'))
    expect(kept.map { |path| File.read(File.join(a_dir, path)) }).to eq(kept)
    expect(File.exist?(yml(a_dir))).to be(false)
  end

  it 'turns an unexpected error into one printed line, never raising' do
    write_yml(a_dir, 'report')
    adapter = fake_adapter_class.new
    adapter.answers['report'] = RuntimeError.new("odd\e[2J")

    expect(cleanup(a_dir, adapter)).to eq('Could not remove the schedules made with Ruby Raider 4.1: odd?[2J')
    expect([err.string, File.exist?(yml(a_dir))]).to eq(["Could not remove the schedules made with Ruby Raider 4.1: odd?[2J\n", true])
  end

  describe 'its own entry (last)' do
    let(:events) { [] }
    let(:recording_err) do
      log = events
      Class.new do
        define_method(:puts) { |text| log << [:puts, text] }
        define_method(:flush) { log << [:flush] }
      end.new
    end
    let(:adapter) do
      fake_adapter_class.new([os_id(a_dir, 'report'), os_id(a_dir, 'other')]).tap do |double|
        log = events
        path = yml(a_dir)
        double.on_remove = ->(id) { log << [:remove, id.split('.').last, File.exist?(path)] }
      end
    end

    def own_cleanup = described_class.new(project(a_dir), adapter: adapter, err: recording_err).cleanup(last: 'report')

    it 'is counted, and removed after the notice is out and the yml deleted' do
      write_yml(a_dir, 'report')

      notice = own_cleanup

      expect(notice).to eq(removed_notice('other', 'report'))
      expect(events).to eq([[:remove, 'other', true], [:puts, notice], [:flush], [:remove, 'report', false]])
    end

    it 'says so on a second line when it can not be removed' do
      adapter.answers['report'] = RubyRaider::Schedules::Error.new('denied')

      own_cleanup

      expect(events.select { |event| event.first == :puts }.map(&:last)).to eq([removed_notice('other', 'report'), 'Could not remove report: denied'])
    end

    it 'is not removed when it is not one of the names' do
      adapter.ids = [os_id(a_dir, 'other')]

      expect(described_class.new(project(a_dir), adapter: adapter, err: err).cleanup(last: 'report')).to eq(removed_notice('other'))
      expect(adapter.calls.drop(1)).to eq(removed('other'))
    end
  end

  it 'prints no flow word' do
    write_yml(a_dir, 'alpha', 'beta')
    adapter = fake_adapter_class.new
    adapter.answers['beta'] = RubyRaider::Schedules::Error.new('busy')
    cleanup(a_dir, adapter)

    expect(err.string).not_to match(/\bflows?\b/i)
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
