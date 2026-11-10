# frozen_string_literal: true

require 'tmpdir'
require 'rexml/document'
require_relative '../../../../lib/utilities/schedules/os/launchd'
require_relative '../../../../lib/utilities/flows/schedule'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# The fake runner, temp home and project folders sit next to the adapter under test
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::Os::Launchd do # rubocop:disable RSpec/FilePath
  # Records every command and answers from a table (success unless told otherwise); never runs anything
  let(:fake_runner_class) do
    Class.new do
      attr_reader :calls, :answers, :stdin

      def initialize
        @calls = []
        @answers = {}
        @stdin = []
      end

      def call(*argv, stdin_data: nil)
        @calls << argv
        @stdin << stdin_data
        @seen&.call(argv)
        stderr, status = answers.fetch(argv[1], ['', 0])
        RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: '', stderr: stderr, exitstatus: status)
      end

      def on_call(&block) = @seen = block
    end
  end

  let(:hostile) { %q('; rm -rf ~; ' </string> %h $(id) " \\ &) }
  let(:tmp) { File.realpath(Dir.mktmpdir('flows-launchd')) }
  let(:home) { File.join(tmp, 'home') }
  let(:project_dir) { File.join(tmp, 'plain') }
  let(:runner) { fake_runner_class.new }
  let(:launchd) { described_class.new(kind: RubyRaider::Schedules::Kind::FLOW_LEGACY, runner: runner, home: home, uid: 501) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }
  let(:agents) { File.join(home, 'Library', 'LaunchAgents') }

  def schedule(dir: project_dir, **options)
    FileUtils.mkdir_p(dir)
    project = RubyRaider::Flows::Project.new(File.realpath(dir))
    RubyRaider::Flows::Schedule.build(project: project, name: 'report', every: 'day', at: '08:00', now: now, **options)
  end

  # plist XML back to Ruby: dict -> Hash, array -> Array, string -> String, integer -> Integer
  def plist_value(element)
    case element.name
    when 'dict'
      element.elements.to_a.each_slice(2).to_h { |key, value| [key.text, plist_value(value)] }
    when 'array' then element.elements.map { |child| plist_value(child) }
    when 'integer' then Integer(element.text)
    else element.text.to_s
    end
  end

  def parsed(text)
    document = REXML::Document.new(text)
    expect(document.root.name).to eq('plist')
    plist_value(document.root.elements.first)
  end

  # What a daily 08:00 schedule must produce, byte for byte
  def daily_plist(item)
    env = item.env.map { |key, value| "\t\t<key>#{key}</key>\n\t\t<string>#{value}</string>\n" }.join
    args = item.argv.map { |arg| "\t\t<string>#{arg}</string>\n" }.join

    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      \t<key>Label</key>
      \t<string>#{item.os_id}</string>
      \t<key>ProgramArguments</key>
      \t<array>
      #{args.chomp}
      \t</array>
      \t<key>WorkingDirectory</key>
      \t<string>#{item.working_directory}</string>
      \t<key>StandardOutPath</key>
      \t<string>#{item.log_path}</string>
      \t<key>StandardErrorPath</key>
      \t<string>#{item.log_path}</string>
      \t<key>EnvironmentVariables</key>
      \t<dict>
      #{env.chomp}
      \t</dict>
      \t<key>StartCalendarInterval</key>
      \t<dict>
      \t\t<key>Hour</key>
      \t\t<integer>8</integer>
      \t\t<key>Minute</key>
      \t\t<integer>0</integer>
      \t</dict>
      </dict>
      </plist>
    PLIST
  end

  def plist_path(item) = File.join(agents, "#{item.os_id}.plist")

  after { FileUtils.rm_rf(tmp) }

  it 'is called launchd in messages' do
    expect(launchd.label).to eq('launchd')
  end

  describe '#plist' do
    it 'writes the exact plist for a daily schedule' do
      item = schedule
      expect(launchd.plist(item)).to eq(daily_plist(item))
    end

    it 'round-trips every field and never sets RunAtLoad' do
      item = schedule(retries: 2, inputs: %w[env=staging])

      expect(parsed(launchd.plist(item))).to eq(
        'Label' => item.os_id, 'ProgramArguments' => item.argv, 'WorkingDirectory' => item.working_directory,
        'StandardOutPath' => item.log_path, 'StandardErrorPath' => item.log_path, 'EnvironmentVariables' => item.env,
        'StartCalendarInterval' => { 'Hour' => 8, 'Minute' => 0 }
      )
    end

    it 'keeps GEM_HOME and GEM_PATH in the environment when they were captured' do
      allow(RubyRaider::Flows::Schedule).to receive(:captured_gem_env).and_return('GEM_HOME' => '/g/home', 'GEM_PATH' => '/g/path')

      env = parsed(launchd.plist(schedule))['EnvironmentVariables']

      expect(env.slice('LANG', 'GEM_HOME', 'GEM_PATH')).to eq('LANG' => 'en_US.UTF-8', 'GEM_HOME' => '/g/home', 'GEM_PATH' => '/g/path')
    end

    it 'runs every hour at its minute' do
      expect(parsed(launchd.plist(schedule(every: 'hour', at: ':15')))['StartCalendarInterval']).to eq('Minute' => 15)
    end

    it 'runs every weekday as five dicts, Monday 1 to Friday 5' do
      interval = parsed(launchd.plist(schedule(every: 'weekday', at: '18:05')))['StartCalendarInterval']

      expect(interval).to eq((1..5).map { |day| { 'Weekday' => day, 'Hour' => 18, 'Minute' => 5 } })
    end

    it 'runs every week on its day, Sunday 0 and Saturday 6' do
      days = %w[sun mon sat].map { |on| parsed(launchd.plist(schedule(every: 'week', on: on)))['StartCalendarInterval'] }

      expect(days).to eq([0, 1, 6].map { |day| { 'Weekday' => day, 'Hour' => 8, 'Minute' => 0 } })
    end

    describe 'with hostile values in an input and in the project path' do
      let(:item) { schedule(dir: File.join(tmp, "p#{hostile}<", "string> #{hostile}"), inputs: ["note=#{hostile}"]) }
      let(:text) { launchd.plist(item) }

      it 'round-trips them exactly' do
        data = parsed(text)

        expect([data['ProgramArguments'], data['WorkingDirectory'], data['StandardOutPath']]).to eq([item.argv, item.working_directory, item.log_path])
        expect(data['ProgramArguments'].last).to eq("note=#{hostile}")
        expect(item.working_directory).to include('</string>', "'; rm -rf ~; '", '$(id)', '%h', '"', '\\', '&')
      end

      it 'writes them only in escaped form' do
        expect(text).not_to include('</string> ', "'; rm", '" \\')
        expect(text.scan(/&(?!amp;|lt;|gt;|quot;|apos;)/)).to be_empty
        expect(text).to include('&lt;/string&gt;', '&apos;; rm -rf ~; &apos;', '&quot; \\ &amp;', '$(id)', '%h')
      end
    end
  end

  describe '#install' do
    it 'writes the plist 0644, lints it, then boots out and bootstraps it' do
      item = schedule
      path = plist_path(item)
      linted = nil
      runner.on_call { |argv| linted = File.read(argv[2]) if argv[1] == '-lint' }

      launchd.install(item)

      expect(runner.calls).to match([
                                      ['/usr/bin/plutil', '-lint', %r{\A#{Regexp.escape(agents)}/\..+\.tmp\z}],
                                      ['/bin/launchctl', 'bootout', "gui/501/#{item.os_id}"],
                                      ['/bin/launchctl', 'bootstrap', 'gui/501', path]
                                    ])
      expect([File.read(path), linted, format('%o', File.stat(path).mode & 0o777)]).to eq([launchd.plist(item), launchd.plist(item), '644'])
      expect(Dir.children(agents)).to eq([File.basename(path)])
    end

    it 'replaces an existing entry and ignores a bootout that finds nothing' do
      item = schedule
      FileUtils.mkdir_p(agents)
      File.write(plist_path(item), 'old')
      runner.answers['bootout'] = ['Boot-out failed: 3: No such process', 3]

      launchd.install(item)

      expect(runner.calls.map { |argv| argv[1] }).to eq(%w[-lint bootout bootstrap])
      expect(File.read(plist_path(item))).to eq(launchd.plist(item))
    end

    it 'removes the plist and raises with the scheduler error when bootstrap fails' do
      item = schedule
      runner.answers['bootstrap'] = ["Bootstrap failed: 5: Input/output error\e[2J\n", 5]

      expect { launchd.install(item) }.to raise_error(RubyRaider::Flows::Error, %r{launchd.*Bootstrap failed: 5: Input/output error\?\[2J})
      expect(Dir.children(agents)).to be_empty
    end

    it 'says so when the plist a failed bootstrap left can not be deleted' do
      item = schedule
      runner.answers['bootstrap'] = ['Bootstrap failed: 5', 5]
      allow(File).to receive(:unlink).and_call_original
      allow(File).to receive(:unlink).with(plist_path(item)).and_raise(Errno::EACCES)

      expect { launchd.install(item) }.to raise_error(RubyRaider::Flows::Error, /Bootstrap failed: 5; also: Could not remove .*Permission denied/)
    end

    it 'raises a flow error and runs nothing when it can not write the plist' do
      FileUtils.mkdir_p(File.dirname(agents))
      File.write(agents, 'not a folder')

      expect { launchd.install(schedule) }.to raise_error(RubyRaider::Flows::Error, /Could not write .*LaunchAgents/)
      expect([runner.calls, File.read(agents)]).to eq([[], 'not a folder'])
    end

    it 'leaves the entry alone and raises when the plist does not lint' do
      item = schedule
      FileUtils.mkdir_p(agents)
      File.write(plist_path(item), 'old')
      runner.answers['-lint'] = ['bad plist', 1]

      expect { launchd.install(item) }.to raise_error(RubyRaider::Flows::Error, /bad plist/)
      expect([runner.calls.map { |argv| argv[1] }, Dir.children(agents), File.read(plist_path(item))])
        .to eq([['-lint'], [File.basename(plist_path(item))], 'old'])
    end
  end

  describe '#remove' do
    it 'boots out and deletes the plist' do
      item = schedule
      FileUtils.mkdir_p(agents)
      File.write(plist_path(item), 'x')

      expect(launchd.remove(item.os_id)).to be(true)
      expect([runner.calls, File.exist?(plist_path(item))]).to eq([[['/bin/launchctl', 'bootout', "gui/501/#{item.os_id}"]], false])
    end

    it 'is true when only the service was loaded' do
      expect(launchd.remove(schedule.os_id)).to be(true)
    end

    it 'is false when it was already gone' do
      runner.answers['bootout'] = ['Boot-out failed: 3: No such process', 3]

      expect(launchd.remove(schedule.os_id)).to be(false)
    end

    it 'raises when the plist can not be deleted' do
      item = schedule
      allow(File).to receive(:unlink).and_raise(Errno::EACCES)

      expect { launchd.remove(item.os_id) }.to raise_error(RubyRaider::Flows::Error, /Could not remove .*Permission denied/)
      expect(runner.calls).to eq([['/bin/launchctl', 'bootout', "gui/501/#{item.os_id}"]])
    end

    it 'refuses an os_id that is not a flow schedule id' do
      expect { launchd.remove('../../evil') }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end
  end

  describe '#present?' do
    it 'asks launchctl print' do
      item = schedule

      expect(launchd.present?(item.os_id)).to be(true)
      expect(runner.calls).to eq([['/bin/launchctl', 'print', "gui/501/#{item.os_id}"]])
    end

    it 'refuses an os_id that is not a flow schedule id and runs nothing' do
      expect { launchd.present?('../../evil') }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end

    it 'is false when launchctl print fails' do
      runner.answers['print'] = ['Could not find service', 113]

      expect(launchd.present?(schedule.os_id)).to be(false)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
