# frozen_string_literal: true

require 'shellwords'
require 'tmpdir'
require_relative '../../../../lib/utilities/flows/os/cron'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# The fake runner and project folders sit next to the adapter under test
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Flows::Os::Cron do # rubocop:disable RSpec/FilePath
  # Plays crontab: -l prints the current table (or fails), - stores stdin; never runs anything
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
        @calls << [*argv, stdin_data].compact
        verb = argv[1]
        missing = verb == '-l' && table.nil?
        stderr, status = answers.fetch(verb) { missing ? ['no crontab for raider', 1] : ['', 0] }
        stdout = verb == '-l' ? table.to_s : ''
        self.table = stdin_data if verb == '-' && status.zero?
        RubyRaider::Flows::Os::CommandRunner::Result.new(stdout: stdout, stderr: stderr, exitstatus: status)
      end
    end
  end

  let(:hostile) { %q('; rm -rf ~; ' </string> %h $(id) " \\ &) }
  let(:tmp) { File.realpath(Dir.mktmpdir('flows-cron')) }
  let(:project_dir) { File.join(tmp, 'plain') }
  let(:runner) { fake_runner_class.new }
  let(:cron) { described_class.new(runner: runner) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }

  def schedule(dir: project_dir, name: 'report', **options)
    FileUtils.mkdir_p(dir)
    project = RubyRaider::Flows::Project.new(File.realpath(dir))
    RubyRaider::Flows::Schedule.build(project: project, name: name, every: 'day', at: '08:00', now: now, **options)
  end

  # What cron (cronie/vixie do_command.c) hands to /bin/sh: a backslash escapes the next character, an
  # escaped % loses its backslash, any other escaped character keeps it, and an unescaped % would end the
  # command (the rest becomes stdin). Strict: an unescaped % fails the spec.
  def cron_command(text)
    command = +''
    escaped = false
    text.each_char do |char|
      if escaped
        command.chop! if char == '%'
        command << char
        escaped = false
        next
      end
      raise ArgumentError, "unescaped % in #{text.inspect}" if char == '%'

      escaped = char == '\\'
      command << char
    end
    command
  end

  def fields_and_words(line)
    fields = line.split(' ', 6)
    [fields.first(5), Shellwords.split(cron_command(fields.last))]
  end

  def expected_words(item)
    ['cd', item.working_directory, '&&', '/usr/bin/env', *item.env.map { |key, value| "#{key}=#{value}" }, *item.argv,
     '>>', item.log_path, '2>&1']
  end

  def block(item) = "# raider-flow #{item.os_id}\n#{cron.line(item)}\n"

  after { FileUtils.rm_rf(tmp) }

  it 'is called cron in messages and says missed runs are skipped' do
    expect([cron.label, cron.missed_runs_note]).to eq(['cron', '(cron: missed runs are skipped)'])
  end

  describe '#line' do
    it 'writes the exact line for a daily schedule' do
      item = schedule
      env = item.env.map { |key, value| Shellwords.escape("#{key}=#{value}") }.join(' ')
      args = item.argv.map { |arg| Shellwords.escape(arg) }.join(' ')

      expect(cron.line(item)).to eq("0 8 * * * cd #{Shellwords.escape(item.working_directory)} && /usr/bin/env #{env} #{args} " \
                                    ">> #{Shellwords.escape(item.log_path)} 2>&1")
    end

    it 'turns each rule into cron fields, Sunday 0' do
      rules = [schedule(every: 'hour', at: ':15'), schedule(every: 'weekday', at: '18:05'),
               schedule(every: 'week', on: 'sun', at: '07:30'), schedule(every: 'week', on: 'sat', at: '23:59')]

      expect(rules.map { |item| fields_and_words(cron.line(item)).first.join(' ') })
        .to eq(['15 * * * *', '5 18 * * 1-5', '30 7 * * 0', '59 23 * * 6'])
    end

    it 'keeps GEM_HOME and GEM_PATH in the environment when they were captured' do
      allow(RubyRaider::Flows::Schedule).to receive(:captured_gem_env).and_return('GEM_HOME' => '/g/%home', 'GEM_PATH' => '/g/path')

      expect(fields_and_words(cron.line(schedule)).last).to include('GEM_HOME=/g/%home', 'GEM_PATH=/g/path')
    end

    it 'refuses a ruby path env would read as a variable' do
      plain = schedule
      item = RubyRaider::Flows::Schedule.from_h(plain.to_h.merge('ruby' => '/opt/a=b/ruby'), plain.project_root)

      expect { cron.line(item) }.to raise_error(RubyRaider::Flows::Error, /cron can not run ruby from .*a=b/)
    end

    describe 'with hostile values in an input and in the project path' do
      let(:item) { schedule(dir: File.join(tmp, "p#{hostile}<", "string> #{hostile} 100%"), inputs: ["note=#{hostile} 50%"]) }
      let(:text) { cron.line(item) }

      it 'gives back the exact command words after cron and the shell read it' do
        fields, words = fields_and_words(text)

        expect([fields, words]).to eq([%w[0 8 * * *], expected_words(item)])
        expect(words).to include("note=#{hostile} 50%")
        expect(item.working_directory).to include('</string>', "'; rm -rf ~; '", '$(id)', '%h', '"', '\\', '&', ' ')
      end

      it 'writes them only in escaped form' do
        expect(text).to include('\\%h', '\\$\\(id\\)', "\\'\\;\\ rm")
        expect(text).not_to include('$(id)', "'; rm", "\n")
      end
    end
  end

  describe '#install' do
    it 'starts a crontab when there is none' do
      item = schedule

      cron.install(item)

      expect(runner.calls).to eq([%w[crontab -l], ['crontab', '-', block(item)]])
    end

    it 'puts the block first and keeps every other byte, CRLF and a missing last newline included' do
      item = schedule
      other = "SHELL=/bin/fish\r\nMAILTO=\"\"\r\n# raider-flow dev.rubyraider.flow.0123456789.other\n1 2 * * * echo % \\%\n5 5 * * * last"
      runner.table = other

      cron.install(item)

      expect(runner.table).to eq(block(item) + other)
    end

    it 'replaces its own block and nothing else' do
      item = schedule
      daily = block(item)
      runner.table = "1 * * * * a\n#{daily}2 * * * * b\n"

      cron.install(schedule(every: 'hour', at: ':10'))

      expect(runner.table).to eq("#{block(schedule(every: 'hour', at: ':10'))}1 * * * * a\n2 * * * * b\n")
      expect(runner.table).not_to include(daily)
    end

    it 'keeps another flow block' do
      other = schedule(name: 'nightly')
      runner.table = block(other)

      cron.install(schedule)

      expect(runner.table).to eq(block(schedule) + block(other))
    end

    it 'refuses a line vixie cron would cut short and writes nothing' do
      item = schedule(inputs: ["note=#{'x' * 900}"])

      expect { cron.install(item) }.to raise_error(RubyRaider::Flows::Error, /crontab line is \d{4} bytes, over 990/)
      expect(runner.calls).to be_empty
    end

    it 'raises with the scheduler error when crontab -l fails for another reason' do
      runner.answers['-l'] = ["crontab: permission denied\e[2J", 1]

      expect { cron.install(schedule) }.to raise_error(RubyRaider::Flows::Error, /cron could not read .*permission denied\?\[2J/)
      expect(runner.calls).to eq([%w[crontab -l]])
    end

    it 'raises with the scheduler error when crontab - fails' do
      runner.table = "1 * * * * a\n"
      runner.answers['-'] = ['crontab: errors in crontab file', 1]

      expect { cron.install(schedule) }.to raise_error(RubyRaider::Flows::Error, /cron could not save .*errors in crontab file/)
      expect(runner.table).to eq("1 * * * * a\n")
    end
  end

  describe '#remove' do
    it 'removes its block and gives back the crontab byte for byte' do
      other = "A=1\r\n1 * * * * a\n2 * * * * b"
      runner.table = other
      cron.install(schedule)

      expect(cron.remove(schedule.os_id)).to be(true)
      expect(runner.table).to eq(other)
    end

    it 'removes every copy of its block' do
      item = schedule
      runner.table = "#{block(item)}1 * * * * a\n#{block(item)}"

      expect(cron.remove(item.os_id)).to be(true)
      expect(runner.table).to eq("1 * * * * a\n")
    end

    it 'keeps an unrelated line that follows an orphaned tag' do
      item = schedule
      other = schedule(name: 'nightly')
      runner.table = "# raider-flow #{item.os_id}\n#{cron.line(other)}\n1 * * * * a\n"

      expect(cron.remove(item.os_id)).to be(true)
      expect(runner.table).to eq("#{cron.line(other)}\n1 * * * * a\n")
    end

    it 'keeps a line under its tag that is not a schedule run' do
      item = schedule
      manual = cron.line(item).sub(' --trigger schedule', ' --trigger manual')
      runner.table = "# raider-flow #{item.os_id}\n#{manual}\n"

      expect(cron.remove(item.os_id)).to be(true)
      expect(runner.table).to eq("#{manual}\n")
    end

    it 'removes a tag line left without its line' do
      item = schedule
      runner.table = "1 * * * * a\n# raider-flow #{item.os_id}"

      expect(cron.remove(item.os_id)).to be(true)
      expect(runner.table).to eq("1 * * * * a\n")
    end

    it 'is false and writes nothing when its block is not there' do
      runner.table = "1 * * * * a\n# raider-flow #{schedule.os_id}x\n"

      expect(cron.remove(schedule.os_id)).to be(false)
      expect(runner.calls).to eq([%w[crontab -l]])
    end

    it 'is false when there is no crontab' do
      expect(cron.remove(schedule.os_id)).to be(false)
    end

    it 'refuses an os_id that is not a flow schedule id' do
      expect { cron.remove("x\n* * * * * evil") }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end
  end

  describe '#usable?' do
    it 'is true when crontab -l answers, even with no crontab' do
      expect(cron.usable?).to be(true)
    end

    it 'is false when crontab -l fails for another reason' do
      runner.answers['-l'] = ['crontab: not found', 127]

      expect(cron.usable?).to be(false)
    end
  end

  describe '#present?' do
    it 'is true when the tag line is there' do
      item = schedule
      runner.table = block(item)

      expect(cron.present?(item.os_id)).to be(true)
    end

    it 'is false when there is no crontab or no tag line' do
      expect(cron.present?(schedule.os_id)).to be(false)
      runner.table = "1 * * * * a\n"
      expect(cron.present?(schedule.os_id)).to be(false)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
