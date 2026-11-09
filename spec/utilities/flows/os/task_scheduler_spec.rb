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
        stderr, status = answers.fetch(argv[1], ['', 0])
        RubyRaider::Flows::Os::CommandRunner::Result.new(stdout: '', stderr: stderr, exitstatus: status)
      end

      def on_call(&block) = @seen = block
    end
  end

  let(:hostile) { %q('; rm -rf ~; ' </string> %h $(id) " \\ &) }
  let(:tmp) { File.realpath(Dir.mktmpdir('flows-schtasks')) }
  let(:project_dir) { File.join(tmp, 'plain') }
  let(:runner) { fake_runner_class.new }
  let(:clock) { Struct.new(:now).new(Time.new(2026, 11, 9, 10, 30, 0)) }
  let(:scheduler) { described_class.new(runner: runner, clock: clock) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }

  def schedule(dir: project_dir, **options)
    FileUtils.mkdir_p(dir)
    project = RubyRaider::Flows::Project.new(File.realpath(dir))
    RubyRaider::Flows::Schedule.build(project: project, name: 'report', every: 'day', at: '08:00', now: now, **options)
  end

  def task_name(item) = "\\RubyRaider\\#{item.os_id}"

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
            <StartBoundary>2026-11-09T08:00:00</StartBoundary>
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
      '%h&$(id)' => '%h&$(id)'
    }.each do |arg, quoted|
      it "quotes #{arg.inspect} as #{quoted.inspect}" do
        expect(described_class.quote(arg)).to eq(quoted)
      end
    end

    it 'gives back every argument when the joined line is split by CommandLineToArgvW rules' do
      args = ['', 'C:\\path with space\\', 'a\\"b', '\\\\', '"', 'x\\', "'; rm -rf ~; '", '</string>', '%h', '$(id)', '\\', '&', hostile]

      expect(split_arguments(described_class.join(args))).to eq(args)
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

    it 'runs every hour from today 00:MM, repeating hourly for a day' do
      trigger = parsed(scheduler.task_xml(schedule(every: 'hour', at: ':15'))).elements['Task/Triggers/CalendarTrigger']

      expect(trigger.elements.map(&:name)).to eq(%w[Repetition StartBoundary Enabled ScheduleByDay])
      expect(%w[Repetition/Interval Repetition/Duration StartBoundary ScheduleByDay/DaysInterval].map { |path| trigger.elements[path].text })
        .to eq(%w[PT1H P1D 2026-11-09T00:15:00 1])
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
        trigger.elements['ScheduleByWeek/DaysOfWeek'].elements.map(&:name)
      end

      expect(days).to eq([%w[Monday], %w[Saturday], %w[Sunday]])
    end

    describe 'with hostile values in an input and in the project path' do
      let(:item) { schedule(dir: File.join(tmp, "p#{hostile}<", "string> #{hostile}"), inputs: ["note=#{hostile}"]) }
      let(:text) { scheduler.task_xml(item) }

      it 'round-trips them through CRT quoting and XML escaping' do
        args = split_arguments(field(text, 'Task/Actions/Exec/Arguments'))

        expect(args).to eq(item.argv.drop(1))
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

  describe '#install' do
    it 'writes the task as UTF-16LE with a BOM, creates it with schtasks and deletes the file' do
      item = schedule
      written = nil
      path = nil
      runner.on_call { |argv, _| written = File.binread(path = argv[5]) if argv[1] == '/Create' }

      expect(scheduler.install(item)).to be(true)
      expect(runner.calls).to eq([['schtasks', '/Create', '/TN', task_name(item), '/XML', path, '/F']])
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
    it 'queries, then deletes the task' do
      item = schedule

      expect(scheduler.remove(item.os_id)).to be(true)
      expect(runner.calls).to eq([['schtasks', '/Query', '/TN', task_name(item)], ['schtasks', '/Delete', '/TN', task_name(item), '/F']])
    end

    it 'is false when it was already gone' do
      item = schedule
      runner.answers['/Query'] = ['ERROR: The system cannot find the file specified.', 1]

      expect(scheduler.remove(item.os_id)).to be(false)
      expect(runner.calls).to eq([['schtasks', '/Query', '/TN', task_name(item)]])
    end

    it 'raises with the scheduler error when the delete fails' do
      runner.answers['/Delete'] = ["ERROR: Access\e is denied.\n", 1]

      expect { scheduler.remove(schedule.os_id) }.to raise_error(RubyRaider::Flows::Error, /Task Scheduler could not delete .*Access\? is denied\.\z/)
    end

    it 'refuses an os_id that is not a flow schedule id' do
      expect { scheduler.remove('..\\..\\evil') }.to raise_error(RubyRaider::Flows::Error, /Invalid os_id/)
      expect(runner.calls).to be_empty
    end
  end

  describe '#present?' do
    it 'asks schtasks /Query' do
      item = schedule

      expect(scheduler.present?(item.os_id)).to be(true)
      expect(runner.calls).to eq([['schtasks', '/Query', '/TN', task_name(item)]])
    end

    it 'is false when the query fails' do
      runner.answers['/Query'] = ['ERROR: The system cannot find the file specified.', 1]

      expect(scheduler.present?(schedule.os_id)).to be(false)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
