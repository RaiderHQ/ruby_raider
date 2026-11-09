# frozen_string_literal: true

require 'tempfile'
require_relative 'command_runner'
require_relative '../schedule'
require_relative '../next_run'

module RubyRaider
  module Flows
    module Os
      # Windows: one task per schedule in the \RubyRaider\ folder, registered from task XML with schtasks.
      # The task runs ruby.exe directly (never cmd.exe or powershell), with the user's own environment and
      # no log file: the outcome lives in runs.jsonl like any flow run. Argument values get Windows CRT
      # quoting, then every value in the XML goes through one XML escaper.
      # Task Scheduler expands %NAME% in Command, Arguments and WorkingDirectory with no escape, so a value
      # holding one is refused before schtasks runs.
      # :reek:TooManyConstants { max_constants: 7 } -- the folder, the XML escapes and namespace, the os_id rule, quoting, %NAME%, day names
      class TaskScheduler
        FOLDER = '\\RubyRaider\\'
        ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;' }.freeze
        NAMESPACE = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
        OS_ID = /\A#{Regexp.escape(Schedule::OS_ID_PREFIX)}\.[0-9a-f]{10}\.([a-z0-9_]{1,60})\z/
        # ruby.exe reads its own command line (win32.c): ' quotes too, and an unquoted * ? [ { is a glob
        NEEDS_QUOTES = /[ \t\n\v"'*?\[{]/
        EXPANDS = /%[^%]+%/
        DAY_NAMES = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

        # One argument as CommandLineToArgvW, the MSVCRT and ruby.exe read it back: quoted when empty or
        # holding whitespace, a quote or a glob character; backslashes are doubled only before a quote (or the closing quote)
        def self.quote(arg)
          return arg if !arg.empty? && !arg.match?(NEEDS_QUOTES)

          body = arg.gsub(/(\\*)"/) { "#{Regexp.last_match(1).to_s * 2}\\\"" }.sub(/(\\+)\z/) { Regexp.last_match(1).to_s * 2 }
          "\"#{body}\""
        end

        def self.join(args) = args.map { |arg| quote(arg) }.join(' ')

        def initialize(runner: CommandRunner.new, clock: Time, schtasks: File.join(ENV.fetch('SystemRoot', 'C:\\Windows'), 'System32', 'schtasks.exe'))
          @runner = runner
          @clock = clock
          @schtasks = schtasks
        end

        def label = 'Task Scheduler'

        def task_name(os_id) = "#{FOLDER}#{checked_os_id(os_id)}"

        # The task XML (a UTF-8 String; install writes it as UTF-16LE with a BOM)
        def task_xml(schedule)
          refuse_expansion(schedule)
          body = [
            element('RegistrationInfo', [text('Description', "Ruby Raider flow #{schedule.name} (#{schedule.rule_text})"),
                                         text('URI', task_name(schedule.os_id))]),
            element('Triggers', element('CalendarTrigger', trigger(schedule))),
            element('Principals', element('Principal id="Author"', [text('LogonType', 'InteractiveToken'), text('RunLevel', 'LeastPrivilege')])),
            element('Settings', settings),
            element('Actions Context="Author"', element('Exec', action(schedule)))
          ]
          lines = ['<?xml version="1.0" encoding="UTF-16"?>', %(<Task version="1.2" xmlns="#{NAMESPACE}">), *indent(body.flatten), '</Task>']
          "#{lines.join("\n")}\n"
        end

        # Registers (or replaces) the task from a UTF-16LE temp file, deleted whatever happens
        def install(schedule)
          os_id = schedule.os_id
          file = Tempfile.new(['raider-flow-task', '.xml'], binmode: true)
          file.write("\uFEFF#{task_xml(schedule)}".encode(Encoding::UTF_16LE))
          file.close
          result = schtasks('/Create', '/TN', task_name(os_id), '/XML', file.path.to_s, '/F')
          return true if result.success?

          raise Error, "Task Scheduler could not create #{os_id}: #{Flows.printable(result.stderr.strip)}"
        ensure
          file&.close!
        end

        # True when the task was deleted, false when it was already gone. schtasks words "not found" in
        # the system language, so a failed delete is checked against the task list; a list that can not
        # be read, or still shows the task, is an error.
        def remove(os_id)
          name = task_name(os_id)
          result = schtasks('/Delete', '/TN', name, '/F')
          return true if result.success?

          listing = list
          return false if listing.success? && !listed?(listing, name)

          raise Error, "Task Scheduler could not delete #{os_id}: #{Flows.printable(result.stderr.strip)}"
        end

        def present?(os_id)
          name = task_name(os_id)
          listing = list
          return listed?(listing, name) if listing.success?

          raise Error, "Task Scheduler could not list tasks: #{Flows.printable(listing.stderr.strip)}"
        end

        private

        def schtasks(*args) = @runner.call(@schtasks, *args)

        # Every task, one CSV row each, the full task name in the first field
        def list = schtasks('/Query', '/FO', 'CSV', '/NH')

        def listed?(listing, name) = listing.stdout.each_line.any? { |line| line.start_with?(%("#{name}",)) }

        def refuse_expansion(schedule)
          value = [schedule.ruby, *schedule.argv.drop(1), schedule.working_directory].find { |item| item.match?(EXPANDS) }
          return unless value

          raise Error, "Task Scheduler would expand #{Flows.printable(value[EXPANDS])} as an environment variable in #{Flows.printable(value.inspect)}: " \
                       'remove the %...% from it'
        end

        def checked_os_id(os_id)
          return os_id if os_id.is_a?(String) && (match = OS_ID.match(os_id)) && Flows.valid_name?(match[1])

          raise Error, "Invalid os_id #{Flows.printable(os_id.inspect)}: not a flow schedule"
        end

        def escape(value) = value.to_s.gsub(/[&<>"']/, ESCAPES)

        def text(name, value) = ["<#{name}>#{escape(value)}</#{name}>"]

        # tag may carry fixed attributes ('Principal id="Author"'); the closing tag is its first word
        def element(tag, children) = ["<#{tag}>", *indent(children.flatten), "</#{tag.split.first}>"]

        def indent(lines) = lines.map { |line| "  #{line}" }

        # Local time without an offset, never in the past (StartWhenAvailable would run a missed start at
        # once): the next run's date, at the rule's own HH:MM so a DST-shifted next run does not move the
        # daily time; an hour rule starts at its next run.
        def trigger(schedule)
          every = schedule.every
          next_run = NextRun.after(schedule, @clock.now)
          hour = every == 'hour' ? next_run.hour : schedule.hour
          start = format('%<date>sT%<hour>02d:%<minute>02d:00', date: next_run.strftime('%Y-%m-%d'), hour: hour, minute: schedule.minute)
          repeat = every == 'hour' ? [element('Repetition', [text('Interval', 'PT1H'), text('Duration', 'P1D')])] : []
          [*repeat, text('StartBoundary', start), text('Enabled', 'true'), *calendar(schedule, every)]
        end

        def calendar(schedule, every)
          return element('ScheduleByDay', text('DaysInterval', '1')) if %w[hour day].include?(every)

          days = schedule.days.map { |day| ["<#{DAY_NAMES.fetch(Schedule::DAYS.index(day).to_i)} />"] }
          element('ScheduleByWeek', [element('DaysOfWeek', days), text('WeeksInterval', '1')])
        end

        def settings
          [text('MultipleInstancesPolicy', 'IgnoreNew'), text('DisallowStartIfOnBatteries', 'false'),
           text('StopIfGoingOnBatteries', 'false'), text('StartWhenAvailable', 'true'), text('Enabled', 'true')]
        end

        def action(schedule)
          ruby, *args = schedule.argv
          [text('Command', ruby), text('Arguments', self.class.join(args)), text('WorkingDirectory', schedule.working_directory)]
        end
      end
    end
  end
end
