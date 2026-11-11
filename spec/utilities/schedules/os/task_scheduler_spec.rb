# frozen_string_literal: true

require 'tmpdir'
require 'rexml/document'
require_relative '../../../../lib/utilities/schedules/os/task_scheduler'
require_relative '../../../../lib/utilities/schedules/schedule'

# The fake runner, fixed clock and project folders sit next to the adapter under test
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::Os::TaskScheduler do # rubocop:disable RSpec/FilePath
  # Records every command and answers from a table keyed by the schtasks verb; never runs anything
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
        stderr, status, stdout = answers.fetch(argv[1], ['', 0])
        RubyRaider::Schedules::Os::CommandRunner::Result.new(stdout: stdout.to_s, stderr: stderr, exitstatus: status)
      end

      def on_call(&block) = @seen = block
    end
  end

  let(:hostile) { %q('; rm -rf ~; ' </string> %h $(id) " \\ &) }
  let(:tmp) { File.realpath(Dir.mktmpdir('schedules-schtasks')) }
  let(:project_dir) { File.join(tmp, 'plain') }
  let(:runner) { fake_runner_class.new }
  let(:clock) { Struct.new(:now).new(Time.new(2026, 11, 9, 10, 30, 0)) }
  let(:schtasks) { 'C:\\Windows\\System32\\schtasks.exe' }
  let(:scheduler) { described_class.new(kind: RubyRaider::Schedules::Kind::TESTS, runner: runner, clock: clock, schtasks: schtasks) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }

  def schedule(dir: project_dir, gem_env: {}, bundle: '/opt/ruby/bin/bundle', **options)
    FileUtils.mkdir_p(dir)
    # Hermetic: the GEM_HOME/GEM_PATH and bundle this spec runs with never reach the entry; a spec passes its own
    allow(RubyRaider::Schedules::Schedule).to receive_messages(captured_gem_env: gem_env, bundle_path: bundle)
    project = RubyRaider::Schedules::Project.new(File.realpath(dir))
    RubyRaider::Schedules::Schedule.build(project: project, name: 'report', every: 'day', at: '08:00', now: now, **options)
  end

  def task_name(item) = "\\RubyRaider\\#{item.os_id}"

  # schtasks /Query /FO CSV /NH: one row per task, full name first
  def csv_rows(*names) = names.map { |name| %("#{name}","11/10/2026 8:00:00 AM","Ready"\r\n) }.join

  def list_call = [schtasks, '/Query', '/FO', 'CSV', '/NH']

  # CommandLineToArgvW / MSVCRT rules for the arguments after the program name: 2n backslashes and a
  # quote give n backslashes and toggle quoting, 2n+1 give n and a literal quote, other backslashes are
  # literal, unquoted space or tab splits. The quoter never writes "" inside quotes, so the post-2008
  # MSVCRT "" rule never applies.
  def split_arguments(line)
    args = []
    current = nil
    quoted = false
    index = 0
    while index < line.length
      char = line[index]
      if char == '\\'
        run = line[index..][/\A\\+/].length
        index += run
        if line[index] == '"'
          current = "#{current}#{'\\' * (run / 2)}"
          if run.odd?
            current += '"'
            index += 1
          end
        else
          current = "#{current}#{'\\' * run}"
        end
        next
      elsif char == '"'
        quoted = !quoted
        current ||= +''
      elsif [' ', "\t"].include?(char) && !quoted
        args << current if current
        current = nil
      else
        current = "#{current}#{char}"
      end
      index += 1
    end
    args << current if current
    args
  end

  # ruby.exe's own reading: a port of w32_cmdvector in ruby/win32/win32.c. Pass 1 splits on unquoted
  # space, tab or newline (' and " both quote; a backslash counts toward escaping a quote except inside
  # '...'), and marks a * ? [ { outside '...' (even inside "...") for globbing. Pass 2 strips the quotes:
  # an even run of backslashes before a quote of the other kind is left as it is, every other quote eats
  # (run + 1) / 2 backslashes. A globbed element is refused here: the quoter must never produce one.
  def ruby_split_arguments(line)
    elements = []
    index = 0
    loop do
      index += 1 while line[index]&.match?(/[ \t\n\v\f\r]/)
      break if index >= line.length

      element, index, glob = ruby_element(line, index)
      raise "ruby.exe would glob #{element.inspect} in #{line.inspect}" if glob

      elements << element
    end
    elements
  end

  def ruby_element(line, index)
    base = index
    quote = nil
    slashes = 0
    glob = false
    done = false
    while !done && index < line.length
      char = line[index]
      case char
      when '\\' then slashes += 1 unless quote == "'"
      when ' ', "\t", "\n"
        done = true unless quote
        slashes = 0
      when '*', '?', '[', '{'
        glob = true unless quote == "'"
        slashes = 0
      when "'", '"'
        if slashes.even?
          if quote.nil? then quote = char
          elsif quote == char
            index += 1 if char == '"' && line[index + 1] == '"'
            quote = nil
          end
        end
        slashes = 0
      else slashes = 0
      end
      index += 1
    end
    length = index - base - (done ? 1 : 0)
    [ruby_unquote(line[base, length]), index, glob]
  end

  def ruby_unquote(text)
    chars = text.chars
    at = 0
    slashes = 0
    quote = nil
    while at < chars.length
      char = chars[at]
      if char == '\\'
        at += 1
        slashes += 1 unless quote == "'"
        next
      end
      unless ["'", '"'].include?(char)
        at += 1
        slashes = 0
        next
      end
      if slashes.even? && quote && quote != char
        at += 1
        slashes = 0
        next
      end
      eaten = (slashes + 1) / 2
      chars.slice!(at - eaten, eaten + (slashes.even? ? 1 : 0))
      at -= eaten
      if slashes.odd?
        at += 1
      elsif quote
        at += 1 if quote == '"' && chars[at] == '"'
        quote = nil
      else
        quote = char
      end
      slashes = 0
    end
    chars.join
  end

  def parsed(text) = REXML::Document.new(text)

  def field(text, path) = parsed(text).elements[path]&.text.to_s

  # What a daily 08:00 schedule must produce, byte for byte
  def daily_xml(item)
    args = described_class.join(item.argv.drop(1))

    <<~XML
      <?xml version="1.0" encoding="UTF-16"?>
      <Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
        <RegistrationInfo>
          <Description>Ruby Raider schedule report (every day at 08:00)</Description>
          <URI>\\RubyRaider\\#{item.os_id}</URI>
        </RegistrationInfo>
        <Triggers>
          <CalendarTrigger>
            <StartBoundary>2026-11-10T08:00:00</StartBoundary>
            <Enabled>true</Enabled>
            <ScheduleByDay>
              <DaysInterval>1</DaysInterval>
            </ScheduleByDay>
          </CalendarTrigger>
        </Triggers>
        <Principals>
          <Principal id="Author">
            <LogonType>InteractiveToken</LogonType>
            <RunLevel>LeastPrivilege</RunLevel>
          </Principal>
        </Principals>
        <Settings>
          <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
          <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
          <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
          <StartWhenAvailable>true</StartWhenAvailable>
          <Enabled>true</Enabled>
        </Settings>
        <Actions Context="Author">
          <Exec>
            <Command>#{item.ruby}</Command>
            <Arguments>#{args}</Arguments>
            <WorkingDirectory>#{item.working_directory}</WorkingDirectory>
          </Exec>
        </Actions>
      </Task>
    XML
  end

  after { FileUtils.rm_rf(tmp) }

  it 'is called Task Scheduler in messages' do
    expect(scheduler.label).to eq('Task Scheduler')
  end

  it 'names the task under the RubyRaider folder' do
    item = schedule
    expect(scheduler.task_name(item.os_id)).to eq(task_name(item))
  end

  describe '.quote' do
    {
      'plain' => 'plain',
      '' => '""',
      'with space' => '"with space"',
      "tab\there" => "\"tab\there\"",
      'C:\\path with space\\' => '"C:\\path with space\\\\"',
      'C:\\no\\space\\' => 'C:\\no\\space\\',
      'a\\"b' => '"a\\\\\\"b"',
      'say "hi"' => '"say \\"hi\\""',
      'a\\\\b c' => '"a\\\\b c"',
      '%h&$(id)' => '%h&$(id)',
      "O'Brien" => %("O'Brien"),
      'a*b' => "'a*b'",
      'p[1]' => "'p[1]'",
      'q?' => "'q?'",
      '{x}' => "'{x}'",
      'x{1,2}' => "'x{1,2}'",
      'C:\\a b\\*.rb' => "'C:\\a b\\*.rb'",
      'a*"b' => %('a*"b'),
      "a\\'b c" => %("a\\\\\\'b c"),
      "a\\\\'b c" => %("a\\\\'b c")
    }.each do |arg, quoted|
      it "quotes #{arg.inspect} as #{quoted.inspect}" do
        expect(described_class.quote(arg)).to eq(quoted)
      end
    end

    # ruby.exe is the real reader; CommandLineToArgvW agrees except on '...' and on backslashes before '
    it 'gives back every argument when the joined line is read by ruby.exe, and by CommandLineToArgvW where they agree' do
      plain = ['', 'C:\\path with space\\', 'a\\"b', '\\\\', '"', 'x\\', "'; rm -rf ~; '", '</string>', '%h', '$(id)', '\\', '&', hostile,
               "C:\\Users\\O'Brien\\proj", "a=x'", "b=y'", "it's \\\"x\\\" \\"]
      ruby_only = ['p[1]', 'a*b', 'q?', '{x}', 'x{1,2}', 'C:\\a b\\*.rb', 'a*"b\\', "a\\'b c", "a\\\\'b c", "a\\\\\\'b c", "C:\\x\\'q' y"]

      expect(ruby_split_arguments(described_class.join(plain + ruby_only))).to eq(plain + ruby_only)
      expect(split_arguments(described_class.join(plain))).to eq(plain)
    end

    it "refuses an argument with both ' and a glob character" do
      expect { described_class.quote("a'*") }.to raise_error(RubyRaider::Schedules::Error, /can not pass "a'\*" to ruby\.exe/)
    end
  end

  describe '#task_xml' do
    it 'writes the exact task for a daily schedule' do
      item = schedule
      expect(scheduler.task_xml(item)).to eq(daily_xml(item))
    end

    it 'carries no environment and no log file' do
      text = scheduler.task_xml(schedule)

      expect(text).not_to include('scheduler.log', 'Environment', 'GEM_HOME', 'cmd', 'powershell')
    end

    it 'runs ruby with the bundle path and the schedule run arguments' do
      item = schedule(retries: 2, selection: RubyRaider::Schedules::Selection.new(kind: 'tag', tag: 'smoke'))
      text = scheduler.task_xml(item)

      expect(field(text, 'Task/Actions/Exec/Command')).to eq(item.ruby)
      expect(split_arguments(field(text, 'Task/Actions/Exec/Arguments'))).to eq(item.argv.drop(1))
      expect(field(text, 'Task/Actions/Exec/WorkingDirectory')).to eq(item.working_directory)
    end

    it 'starts at the next run: an 11:00 rule at 10:30 starts today at 11:00' do
      trigger = parsed(scheduler.task_xml(schedule(every: 'day', at: '11:00'))).elements['Task/Triggers/CalendarTrigger']

      expect(trigger.elements['StartBoundary'].text).to eq('2026-11-09T11:00:00')
    end

    it 'runs every hour from its next run, repeating hourly for a day' do
      trigger = parsed(scheduler.task_xml(schedule(every: 'hour', at: ':15'))).elements['Task/Triggers/CalendarTrigger']

      expect(trigger.elements.map(&:name)).to eq(%w[Repetition StartBoundary Enabled ScheduleByDay])
      expect(%w[Repetition/Interval Repetition/Duration StartBoundary ScheduleByDay/DaysInterval].map { |path| trigger.elements[path].text })
        .to eq(%w[PT1H P1D 2026-11-09T11:15:00 1])
    end

    it 'runs every weekday Monday to Friday, weekly' do
      trigger = parsed(scheduler.task_xml(schedule(every: 'weekday', at: '18:05'))).elements['Task/Triggers/CalendarTrigger']

      expect(trigger.elements['StartBoundary'].text).to eq('2026-11-09T18:05:00')
      expect(trigger.elements['ScheduleByWeek'].elements.map(&:name)).to eq(%w[DaysOfWeek WeeksInterval])
      expect(trigger.elements['ScheduleByWeek/DaysOfWeek'].elements.map(&:name)).to eq(%w[Monday Tuesday Wednesday Thursday Friday])
      expect(trigger.elements['ScheduleByWeek/WeeksInterval'].text).to eq('1')
    end

    it 'runs every week on its one day' do
      days = %w[mon sat sun].map do |on|
        trigger = parsed(scheduler.task_xml(schedule(every: 'week', on: on))).elements['Task/Triggers/CalendarTrigger']
        [trigger.elements['ScheduleByWeek/DaysOfWeek'].elements.map(&:name), trigger.elements['StartBoundary'].text]
      end

      expect(days).to eq([[%w[Monday], '2026-11-16T08:00:00'], [%w[Saturday], '2026-11-14T08:00:00'], [%w[Sunday], '2026-11-15T08:00:00']])
    end

    # One at a time: a lone % in both would read as %...% across the joined Arguments and be refused
    {
      'the bundle path' => ->(spec) { spec.schedule(bundle: "/opt/#{spec.hostile}/bundle") },
      'the project path' => ->(spec) { spec.schedule(dir: File.join(spec.tmp, 'p<', "string> #{spec.hostile}")) }
    }.each do |where, build|
      describe "with hostile values in #{where}" do
        let(:item) { build.call(self) }
        let(:text) { scheduler.task_xml(item) }

        it 'round-trips them through CRT quoting and XML escaping' do
          line = field(text, 'Task/Actions/Exec/Arguments')

          expect([split_arguments(line), ruby_split_arguments(line)]).to eq([item.argv.drop(1), item.argv.drop(1)])
          expect(field(text, 'Task/Actions/Exec/WorkingDirectory')).to eq(item.working_directory)
          expect(item.argv.join).to include('</string>', "'; rm -rf ~; '", '$(id)', '%h', '"', '\\', '&')
        end

        it 'writes them only in escaped form' do
          expect(text).not_to include('</string>', "'; rm", '" \\')
          expect(text.scan(/&(?!amp;|lt;|gt;|quot;|apos;)/)).to be_empty
          expect(text).to include('&lt;/string&gt;', '&apos;; rm -rf ~; &apos;', '\\&quot; \\ &amp;', '$(id)', '%h')
        end
      end
    end
  end

  describe 'with quotes and glob characters but no spaces' do
    let(:item) { schedule(dir: File.join(tmp, 'Users', "O'Brien", "proj'"), bundle: '/opt/p[1]/a*b/bundle') }

    it "quotes them so ruby.exe reads the exact argv back and globs nothing ('...' around a glob)" do
      line = field(scheduler.task_xml(item), 'Task/Actions/Exec/Arguments')

      expect(ruby_split_arguments(line)).to eq(item.argv.drop(1))
      expect(line).to include(%("#{item.project_root}"), "'/opt/p[1]/a*b/bundle'")
    end

    it "refuses an argument with both ' and a glob character before any schtasks call" do
      expect { scheduler.install(schedule(bundle: "/opt/a'*/bundle")) }.to raise_error(RubyRaider::Schedules::Error, /ruby\.exe/)
      expect(runner.calls).to be_empty
    end
  end

  describe 'with %NAME% that Task Scheduler would expand' do
    it 'refuses it in the bundle path before any schtasks call' do
      item = schedule(bundle: '/opt/%PATH%/bundle')

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Schedules::Error, /Task Scheduler would expand %PATH% as an environment variable/)
      expect(runner.calls).to be_empty
    end

    it 'refuses it in the project path before any schtasks call' do
      item = schedule(dir: File.join(tmp, '%PATH%', 'proj'))

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Schedules::Error, /would expand %PATH%/)
      expect { scheduler.task_xml(item) }.to raise_error(RubyRaider::Schedules::Error, /would expand %PATH%/)
      expect(runner.calls).to be_empty
    end

    it 'refuses a %...% formed across two arguments in the joined Arguments' do
      item = schedule(dir: File.join(tmp, 'y%'), bundle: '/opt/%x/bundle')

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Schedules::Error, %r{would expand %x/bundle exec raider schedule run report --project .*/y%})
      expect(runner.calls).to be_empty
    end

    it 'keeps a lone %' do
      item = schedule(dir: File.join(tmp, '100% sure'))

      expect(split_arguments(field(scheduler.task_xml(item), 'Task/Actions/Exec/Arguments'))).to eq(item.argv.drop(1))
      expect(item.project_root).to end_with('/100% sure')
    end
  end

  describe '#install' do
    it 'writes the task as UTF-16LE with a BOM, creates it with schtasks and deletes the file' do
      item = schedule
      written = nil
      path = nil
      runner.on_call { |argv, _| written = File.binread(path = argv[5]) if argv[1] == '/Create' }

      expect(scheduler.install(item)).to be(true)
      expect(runner.calls).to eq([[schtasks, '/Create', '/TN', task_name(item), '/XML', path, '/F']])
      expect(written.byteslice(0, 2).bytes).to eq([0xFF, 0xFE])
      expect(written.byteslice(2..).force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8)).to eq(scheduler.task_xml(item))
      expect(File.exist?(path)).to be(false)
    end

    it 'raises with the scheduler error and still deletes the file when schtasks fails' do
      item = schedule
      path = nil
      runner.on_call { |argv, _| path = argv[5] }
      runner.answers['/Create'] = ["ERROR: Access is denied.\e[2J\n", 1]

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Schedules::Error, /Task Scheduler.*#{Regexp.escape(item.os_id)}.*Access is denied\.\?\[2J/)
      expect(File.exist?(path)).to be(false)
    end
  end

  describe '#remove' do
    it 'deletes the task' do
      item = schedule

      expect(scheduler.remove(item.os_id)).to be(true)
      expect(runner.calls).to eq([[schtasks, '/Delete', '/TN', task_name(item), '/F']])
    end

    it 'is false when the delete fails and the task list does not show it' do
      item = schedule
      runner.answers['/Delete'] = ['ERROR: The system cannot find the file specified.', 1]
      runner.answers['/Query'] = ['', 0, csv_rows('\\Other', "#{task_name(item)}_old")]

      expect(scheduler.remove(item.os_id)).to be(false)
      expect(runner.calls).to eq([[schtasks, '/Delete', '/TN', task_name(item), '/F'], list_call])
    end

    it 'raises with the delete error when the task list still shows it' do
      item = schedule
      runner.answers['/Delete'] = ["ERROR: Access\e is denied.\n", 1]
      runner.answers['/Query'] = ['', 0, csv_rows('\\Other', task_name(item))]

      expect { scheduler.remove(item.os_id) }.to raise_error(RubyRaider::Schedules::Error, /Task Scheduler could not delete .*Access\? is denied\.\z/)
    end

    it 'raises with the delete error when the task list can not be read' do
      runner.answers['/Delete'] = ['ERROR: Access is denied.', 1]
      runner.answers['/Query'] = ['ERROR: list failed', 1]

      expect { scheduler.remove(schedule.os_id) }.to raise_error(RubyRaider::Schedules::Error, /could not delete .*Access is denied/)
    end

    it 'refuses an os_id that is not a schedule id' do
      expect { scheduler.remove('..\\..\\evil') }.to raise_error(RubyRaider::Schedules::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end
  end

  describe '#present?' do
    it 'is true when the task list shows the exact task name' do
      item = schedule
      runner.answers['/Query'] = ['', 0, csv_rows('\\Other', task_name(item))]

      expect(scheduler.present?(item.os_id)).to be(true)
      expect(runner.calls).to eq([list_call])
    end

    it 'is false when it shows only other tasks' do
      item = schedule
      runner.answers['/Query'] = ['', 0, csv_rows("#{task_name(item)}_old", '\\Other')]

      expect(scheduler.present?(item.os_id)).to be(false)
    end

    it 'raises when the task list can not be read' do
      runner.answers['/Query'] = ["ERROR: no\e list", 1]

      expect { scheduler.present?(schedule.os_id) }.to raise_error(RubyRaider::Schedules::Error, /could not list tasks: ERROR: no\? list/)
    end
  end

  it 'runs schtasks.exe from SystemRoot by default' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SystemRoot', anything).and_return('D:\\Win')
    item = schedule

    described_class.new(kind: RubyRaider::Schedules::Kind::TESTS, runner: runner, clock: clock).remove(item.os_id)

    expect(runner.calls.first.first).to eq(File.join('D:\\Win', 'System32', 'schtasks.exe'))
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
