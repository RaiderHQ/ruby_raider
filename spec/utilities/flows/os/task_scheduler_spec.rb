# frozen_string_literal: true

require 'tmpdir'
require 'rexml/document'
require_relative '../../../../lib/utilities/flows/os/task_scheduler'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
# The fake runner, fixed clock and project folders sit next to the adapter under test
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Flows::Os::TaskScheduler do # rubocop:disable RSpec/FilePath
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
        RubyRaider::Flows::Os::CommandRunner::Result.new(stdout: stdout.to_s, stderr: stderr, exitstatus: status)
      end

      def on_call(&block) = @seen = block
    end
  end

  let(:hostile) { %q('; rm -rf ~; ' </string> %h $(id) " \\ &) }
  let(:tmp) { File.realpath(Dir.mktmpdir('flows-schtasks')) }
  let(:project_dir) { File.join(tmp, 'plain') }
  let(:runner) { fake_runner_class.new }
  let(:clock) { Struct.new(:now).new(Time.new(2026, 11, 9, 10, 30, 0)) }
  let(:schtasks) { 'C:\\Windows\\System32\\schtasks.exe' }
  let(:scheduler) { described_class.new(runner: runner, clock: clock, schtasks: schtasks) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }

  def schedule(dir: project_dir, **options)
    FileUtils.mkdir_p(dir)
    project = RubyRaider::Flows::Project.new(File.realpath(dir))
    RubyRaider::Flows::Schedule.build(project: project, name: 'report', every: 'day', at: '08:00', now: now, **options)
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

  # ruby.exe's own reading (win32.c cmdvector): " quotes with the MSVCRT backslash rules, ' quotes with
  # everything literal inside, and an unquoted * ? [ { would be globbed (refused here: never expected)
  def ruby_split_arguments(line)
    args = []
    current = nil
    quote = nil
    index = 0
    while index < line.length
      char = line[index]
      if char == '\\' && quote != "'"
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
      elsif quote.nil? && ['"', "'"].include?(char)
        quote = char
        current ||= +''
      elsif char == quote
        quote = nil
      elsif quote.nil? && [' ', "\t"].include?(char)
        args << current if current
        current = nil
      else
        raise "unquoted glob character #{char.inspect} in #{line.inspect}" if quote.nil? && '*?[{'.include?(char)

        current = "#{current}#{char}"
      end
      index += 1
    end
    args << current if current
    args
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
          <Description>Ruby Raider flow report (every day at 08:00)</Description>
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
      'a*b' => '"a*b"',
      'p[1]' => '"p[1]"',
      'q?' => '"q?"',
      '{x}' => '"{x}"'
    }.each do |arg, quoted|
      it "quotes #{arg.inspect} as #{quoted.inspect}" do
        expect(described_class.quote(arg)).to eq(quoted)
      end
    end

    it 'gives back every argument when the joined line is split by CommandLineToArgvW rules and by ruby.exe' do
      args = ['', 'C:\\path with space\\', 'a\\"b', '\\\\', '"', 'x\\', "'; rm -rf ~; '", '</string>', '%h', '$(id)', '\\', '&', hostile,
              "C:\\Users\\O'Brien\\proj", "a=x'", "b=y'", 'p[1]', 'a*b', 'q?', '{x}', "it's \\\"x\\\" \\"]
      line = described_class.join(args)

      expect([split_arguments(line), ruby_split_arguments(line)]).to eq([args, args])
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

    it 'runs ruby with the bundle path and the flow run arguments' do
      item = schedule(retries: 2, inputs: %w[env=staging])
      text = scheduler.task_xml(item)

      expect(field(text, 'Task/Actions/Exec/Command')).to eq(item.ruby)
      expect(split_arguments(field(text, 'Task/Actions/Exec/Arguments'))).to eq(item.argv.drop(1))
      expect(field(text, 'Task/Actions/Exec/WorkingDirectory')).to eq(item.working_directory)
    end

    it 'starts at the next run, never in the past (a 08:00 rule at 10:30 starts tomorrow)' do
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

    describe 'with hostile values in an input and in the project path' do
      # hostile once in the path: two lone % around other text would read as %NAME% and be refused
      let(:item) { schedule(dir: File.join(tmp, 'p<', "string> #{hostile}"), inputs: ["note=#{hostile}"]) }
      let(:text) { scheduler.task_xml(item) }

      it 'round-trips them through CRT quoting and XML escaping' do
        line = field(text, 'Task/Actions/Exec/Arguments')
        args = split_arguments(line)

        expect([args, ruby_split_arguments(line)]).to eq([item.argv.drop(1), item.argv.drop(1)])
        expect(args.last).to eq("note=#{hostile}")
        expect(field(text, 'Task/Actions/Exec/WorkingDirectory')).to eq(item.working_directory)
        expect(item.working_directory).to include('</string>', "'; rm -rf ~; '", '$(id)', '%h', '"', '\\', '&')
      end

      it 'writes them only in escaped form' do
        expect(text).not_to include('</string>', "'; rm", '" \\')
        expect(text.scan(/&(?!amp;|lt;|gt;|quot;|apos;)/)).to be_empty
        expect(text).to include('&lt;/string&gt;', '&apos;; rm -rf ~; &apos;', '\\&quot; \\ &amp;', '&quot; \\ &amp;', '$(id)', '%h')
      end
    end
  end

  describe 'with quotes and glob characters but no spaces' do
    let(:item) { schedule(dir: File.join(tmp, 'Users', "O'Brien", 'proj'), inputs: ["a=x'", "b=y'", 'c=p[1]', 'd=a*b']) }

    it 'double-quotes them so CommandLineToArgvW and ruby.exe both read the exact argv back' do
      line = field(scheduler.task_xml(item), 'Task/Actions/Exec/Arguments')

      expect([split_arguments(line), ruby_split_arguments(line)]).to eq([item.argv.drop(1), item.argv.drop(1)])
      expect(line).to include(%("#{item.project_root}"), %("a=x'"), %("b=y'"), '"c=p[1]"', '"d=a*b"')
    end
  end

  describe 'with %NAME% that Task Scheduler would expand' do
    it 'refuses it in an input value before any schtasks call' do
      item = schedule(inputs: ['note=%PATH%'])

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Flows::Error, /Task Scheduler would expand %PATH% as an environment variable/)
      expect(runner.calls).to be_empty
    end

    it 'refuses it in the project path before any schtasks call' do
      item = schedule(dir: File.join(tmp, '%PATH%', 'proj'))

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Flows::Error, /would expand %PATH%/)
      expect { scheduler.task_xml(item) }.to raise_error(RubyRaider::Flows::Error, /would expand %PATH%/)
      expect(runner.calls).to be_empty
    end

    it 'keeps a lone %' do
      item = schedule(inputs: ['note=100% sure', 'other=%h'])

      expect(split_arguments(field(scheduler.task_xml(item), 'Task/Actions/Exec/Arguments')).last(2)).to eq(['note=100% sure', 'other=%h'])
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

      expect { scheduler.install(item) }.to raise_error(RubyRaider::Flows::Error, /Task Scheduler.*#{Regexp.escape(item.os_id)}.*Access is denied\.\?\[2J/)
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

      expect { scheduler.remove(item.os_id) }.to raise_error(RubyRaider::Flows::Error, /Task Scheduler could not delete .*Access\? is denied\.\z/)
    end

    it 'raises with the delete error when the task list can not be read' do
      runner.answers['/Delete'] = ['ERROR: Access is denied.', 1]
      runner.answers['/Query'] = ['ERROR: list failed', 1]

      expect { scheduler.remove(schedule.os_id) }.to raise_error(RubyRaider::Flows::Error, /could not delete .*Access is denied/)
    end

    it 'refuses an os_id that is not a flow schedule id' do
      expect { scheduler.remove('..\\..\\evil') }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
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

      expect { scheduler.present?(schedule.os_id) }.to raise_error(RubyRaider::Flows::Error, /could not list tasks: ERROR: no\? list/)
    end
  end

  it 'runs schtasks.exe from SystemRoot by default' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SystemRoot', anything).and_return('D:\\Win')
    item = schedule

    described_class.new(runner: runner, clock: clock).remove(item.os_id)

    expect(runner.calls.first.first).to eq(File.join('D:\\Win', 'System32', 'schtasks.exe'))
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
