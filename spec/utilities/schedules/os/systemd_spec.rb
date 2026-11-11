# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../../lib/utilities/schedules/os/systemd'
require_relative '../../../../lib/utilities/flows/schedule'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# The fake runner, temp home and project folders sit next to the adapter under test
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::Os::Systemd do # rubocop:disable RSpec/FilePath
  # Records every command and answers from a table keyed by the systemctl verb; never runs anything
  let(:fake_runner_class) do
    Class.new do
      attr_reader :calls, :answers

      def initialize
        @calls = []
        @answers = {}
      end

      def call(*argv, stdin_data: nil)
        @calls << argv
        @seen&.call(argv, stdin_data)
        stderr, status = answers.fetch(argv[2], ['', 0])
        RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: '', stderr: stderr, exitstatus: status)
      end

      def on_call(&block) = @seen = block
    end
  end

  let(:hostile) { %q('; rm -rf ~; ' </string> %h $(id) " \\ &) }
  let(:tmp) { File.realpath(Dir.mktmpdir('flows-systemd')) }
  let(:home) { File.join(tmp, 'home') }
  let(:project_dir) { File.join(tmp, 'plain') }
  let(:runner) { fake_runner_class.new }
  let(:systemd) { described_class.new(kind: RubyRaider::Schedules::Kind::FLOW_LEGACY, runner: runner, home: home, config_home: nil) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }
  let(:units) { File.join(home, '.config', 'systemd', 'user') }

  def schedule(dir: project_dir, **options)
    FileUtils.mkdir_p(dir)
    project = RubyRaider::Flows::Project.new(File.realpath(dir))
    RubyRaider::Flows::Schedule.build(project: project, name: 'report', every: 'day', at: '08:00', now: now, **options)
  end

  # systemd's specifier rule for a raw value: %% is %, any other % would be a specifier
  def unspecify(text)
    text.gsub(/%(.?)/m) do
      raise ArgumentError, "specifier %#{Regexp.last_match(1)} in #{text.inspect}" unless Regexp.last_match(1) == '%'

      '%'
    end
  end

  # Splits a value the way systemd reads ExecStart= (dollars: true) or Environment= (dollars: false): words
  # separated by spaces, each in double quotes with \\ and \" as the only C escapes, %% for %, and in ExecStart
  # $$ for $. Strict: anything else raises, so a value that would be expanded or misread fails the spec.
  # :reek:TooManyStatements
  def systemd_words(text, dollars:)
    words = []
    rest = text.dup
    until rest.empty?
      raise ArgumentError, "unquoted word at #{rest.inspect}" unless rest.start_with?('"')

      word = +''
      index = 1
      loop do
        char = rest[index] or raise ArgumentError, 'unterminated quote'
        index += 1
        break if char == '"'

        if char == '\\'
          escaped = rest[index]
          raise ArgumentError, "C escape \\#{escaped}" unless ['\\', '"'].include?(escaped)

          word << escaped
          index += 1
        elsif char == '%' || (dollars && char == '$')
          raise ArgumentError, "lone #{char}" unless rest[index] == char

          word << char
          index += 1
        else
          word << char
        end
      end
      words << word
      rest = rest[index..].sub(/\A /, '')
    end
    words
  end

  def value_of(text, key) = text.lines.map(&:chomp).select { |line| line.start_with?("#{key}=") }.map { |line| line.delete_prefix("#{key}=") }

  def service_path(item) = File.join(units, "#{item.os_id}.service")

  def timer_path(item) = File.join(units, "#{item.os_id}.timer")

  after { FileUtils.rm_rf(tmp) }

  it 'is called systemd in messages and has no missed runs note' do
    expect([systemd.label, systemd.missed_runs_note]).to eq(['systemd', nil])
  end

  describe '#service' do
    it 'writes the exact unit for a daily schedule' do
      item = schedule
      exec = item.argv.map { |arg| %("#{arg}") }.join(' ')
      env = item.env.map { |key, value| %(Environment="#{key}=#{value}"\n) }.join

      expect(systemd.service(item)).to eq(<<~UNIT)
        [Unit]
        Description=raider flow report

        [Service]
        Type=oneshot
        WorkingDirectory=#{item.working_directory}
        #{env.chomp}
        ExecStart=#{exec}
        StandardOutput=append:#{item.log_path}
        StandardError=append:#{item.log_path}
      UNIT
    end

    it 'keeps GEM_HOME and GEM_PATH in the environment when they were captured' do
      allow(RubyRaider::Flows::Schedule).to receive(:captured_gem_env).and_return('GEM_HOME' => '/g/%h$x', 'GEM_PATH' => '/g/path')

      lines = value_of(systemd.service(schedule), 'Environment').flat_map { |value| systemd_words(value, dollars: false) }

      expect(lines.last(3)).to eq(['LANG=en_US.UTF-8', 'GEM_HOME=/g/%h$x', 'GEM_PATH=/g/path'])
    end

    describe 'with hostile values in an input and in the project path' do
      let(:item) { schedule(dir: File.join(tmp, "p#{hostile}<", "string> #{hostile}"), inputs: ["note=#{hostile}"]) }
      let(:text) { systemd.service(item) }

      it 'gives back the exact argv from ExecStart' do
        argv = systemd_words(value_of(text, 'ExecStart').first, dollars: true)

        expect(argv).to eq(item.argv)
        expect(argv.last).to eq("note=#{hostile}")
        expect(item.working_directory).to include('</string>', "'; rm -rf ~; '", '$(id)', '%h', '"', '\\', '&', ' ')
      end

      it 'gives back the exact paths and environment' do
        env = value_of(text, 'Environment').flat_map { |value| systemd_words(value, dollars: false) }

        expect([unspecify(value_of(text, 'WorkingDirectory').first), value_of(text, 'StandardOutput').map { |value| unspecify(value) }])
          .to eq([item.working_directory, ["append:#{item.log_path}"]])
        expect(env).to eq(item.env.map { |key, value| "#{key}=#{value}" })
      end

      it 'writes them only in escaped form' do
        expect(text).to include('%%h', '$$(id)', '\\" \\\\ &')
        expect(text.scan(/(?<!%)%(?!%)/)).to be_empty
        expect(text.lines.length).to eq(systemd.service(schedule).lines.length)
      end
    end
  end

  describe '#timer' do
    it 'writes the exact timer for a daily schedule' do
      expect(systemd.timer(schedule)).to eq(<<~UNIT)
        [Unit]
        Description=raider flow report schedule

        [Timer]
        OnCalendar=*-*-* 08:00:00
        Persistent=true

        [Install]
        WantedBy=timers.target
      UNIT
    end

    it 'turns each rule into OnCalendar' do
      rules = [schedule(every: 'hour', at: ':15'), schedule(every: 'weekday', at: '18:05'), schedule(every: 'week', on: 'sun', at: '07:30')]

      expect(rules.map { |item| value_of(systemd.timer(item), 'OnCalendar').first })
        .to eq(['*-*-* *:15:00', 'Mon..Fri *-*-* 18:05:00', 'Sun *-*-* 07:30:00'])
    end
  end

  describe '#install' do
    it 'writes both units 0644, reloads, then enables the timer' do
      item = schedule

      systemd.install(item)

      expect(runner.calls).to eq([%w[systemctl --user daemon-reload], ['systemctl', '--user', 'enable', '--now', "#{item.os_id}.timer"]])
      expect([File.read(service_path(item)), File.read(timer_path(item))]).to eq([systemd.service(item), systemd.timer(item)])
      expect([service_path(item), timer_path(item)].map { |path| format('%o', File.stat(path).mode & 0o777) }).to eq(%w[644 644])
      expect(Dir.children(units).sort).to eq([File.basename(service_path(item)), File.basename(timer_path(item))])
    end

    it 'uses an absolute XDG_CONFIG_HOME and ignores a relative one' do
      item = schedule
      config = File.join(tmp, 'xdg')
      described_class.new(kind: RubyRaider::Schedules::Kind::FLOW_LEGACY, runner: runner, home: home, config_home: config).install(item)
      described_class.new(kind: RubyRaider::Schedules::Kind::FLOW_LEGACY, runner: runner, home: home, config_home: 'relative').install(item)

      expect([File.exist?(File.join(config, 'systemd', 'user', "#{item.os_id}.timer")), File.exist?(timer_path(item))]).to eq([true, true])
    end

    it 'replaces existing units' do
      item = schedule
      FileUtils.mkdir_p(units)
      File.write(service_path(item), 'old')
      File.write(timer_path(item), 'old')

      systemd.install(item)

      expect([File.read(service_path(item)), File.read(timer_path(item))]).to eq([systemd.service(item), systemd.timer(item)])
    end

    it 'removes both units, reloads and raises with the scheduler error when enable fails' do
      item = schedule
      runner.answers['enable'] = ["Failed to enable unit\e[2J\n", 1]

      expect { systemd.install(item) }.to raise_error(RubyRaider::Flows::Error, /systemd could not enable .*Failed to enable unit\?\[2J/)
      expect(runner.calls.map { |argv| argv[2] }).to eq(%w[daemon-reload enable disable daemon-reload])
      expect(runner.calls[2]).to eq(['systemctl', '--user', 'disable', "#{item.os_id}.timer"])
      expect(Dir.children(units)).to be_empty
    end

    it 'removes both units when the first reload fails' do
      item = schedule
      runner.answers['daemon-reload'] = ['Failed to connect to bus', 1]

      expect { systemd.install(item) }.to raise_error(RubyRaider::Flows::Error, /Failed to connect to bus/)
      expect(Dir.children(units)).to be_empty
    end

    it 'refuses a project path systemd can not keep, before writing anything' do
      ['trailing ', 'tab\\'].each do |name|
        item = schedule(dir: File.join(tmp, name))

        expect { systemd.install(item) }.to raise_error(RubyRaider::Flows::Error, /systemd can not use the path/)
      end
      expect([runner.calls, File.exist?(units)]).to eq([[], false])
    end

    it 'leaves no temp file behind when writing one fails' do
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(/\.timer\..*\.tmp\z/, any_args).and_wrap_original do |original, path, *rest, **options|
        original.call(path, *rest, **options) { raise Errno::ENOSPC }
      end

      expect { systemd.install(schedule) }.to raise_error(RubyRaider::Flows::Error, /Could not write .*No space left/)
      expect([runner.calls, Dir.children(units)]).to eq([[], []])
    end

    it 'raises a flow error and runs nothing when it can not write the units' do
      FileUtils.mkdir_p(File.dirname(units))
      File.write(units, 'not a folder')

      expect { systemd.install(schedule) }.to raise_error(RubyRaider::Flows::Error, /Could not write .*systemd/)
      expect([runner.calls, File.read(units)]).to eq([[], 'not a folder'])
    end
  end

  describe '#remove' do
    it 'disables the timer, deletes both units and reloads' do
      item = schedule
      FileUtils.mkdir_p(units)
      File.write(service_path(item), 'x')
      File.write(timer_path(item), 'x')

      expect(systemd.remove(item.os_id)).to be(true)
      expect(runner.calls).to eq([['systemctl', '--user', 'disable', '--now', "#{item.os_id}.timer"], %w[systemctl --user daemon-reload]])
      expect(Dir.children(units)).to be_empty
    end

    it 'is false when it was already gone, even if disable fails' do
      runner.answers['disable'] = ['Unit file does not exist', 1]

      expect(systemd.remove(schedule.os_id)).to be(false)
      expect(runner.calls.map { |argv| argv[2] }).to eq(%w[disable daemon-reload])
    end

    it 'raises when a unit can not be deleted' do
      item = schedule
      allow(File).to receive(:unlink).and_raise(Errno::EACCES)

      expect { systemd.remove(item.os_id) }.to raise_error(RubyRaider::Flows::Error, /Could not remove .*Permission denied/)
    end

    it 'raises when the reload fails' do
      runner.answers['daemon-reload'] = ['Failed to connect to bus', 1]

      expect { systemd.remove(schedule.os_id) }.to raise_error(RubyRaider::Flows::Error, /Failed to connect to bus/)
    end

    it 'refuses an os_id that is not a flow schedule id' do
      expect { systemd.remove('../../evil') }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end
  end

  describe '#usable?' do
    it 'asks the user manager for its environment' do
      expect(systemd.usable?).to be(true)
      runner.answers['show-environment'] = ['Failed to connect to bus', 1]
      expect(systemd.usable?).to be(false)
      expect(runner.calls).to eq([%w[systemctl --user show-environment]] * 2)
    end
  end

  describe '#present?' do
    it 'asks whether the timer is enabled' do
      item = schedule

      expect(systemd.present?(item.os_id)).to be(true)
      expect(runner.calls).to eq([['systemctl', '--user', 'is-enabled', "#{item.os_id}.timer"]])
    end

    it 'is false when the timer is not enabled' do
      runner.answers['is-enabled'] = ['disabled', 1]

      expect(systemd.present?(schedule.os_id)).to be(false)
    end

    it 'refuses an os_id that is not a flow schedule id and runs nothing' do
      expect { systemd.present?('x; rm') }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
