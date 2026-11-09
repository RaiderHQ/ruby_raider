# frozen_string_literal: true

require 'tempfile'
require_relative 'command_runner'
require_relative '../schedule'

module RubyRaider
  module Flows
    module Os
      # Windows: one task per schedule in the \RubyRaider\ folder, registered from task XML with schtasks.
      # The task runs ruby.exe directly (never cmd.exe or powershell), with the user's own environment and
      # no log file: the outcome lives in runs.jsonl like any flow run. Argument values get Windows CRT
      # quoting, then every value in the XML goes through one XML escaper.
      # :reek:TooManyConstants { max_constants: 7 } -- the tool, the folder, the XML escapes and namespace, the os_id rule, quoting, day names
      class TaskScheduler
        SCHTASKS = 'schtasks'
        FOLDER = '\\RubyRaider\\'
        ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;' }.freeze
        NAMESPACE = 'http://schemas.microsoft.com/windows/2004/02/mit/task'
        OS_ID = /\A#{Regexp.escape(Schedule::OS_ID_PREFIX)}\.[0-9a-f]{10}\.([a-z0-9_]{1,60})\z/
        NEEDS_QUOTES = /[ \t\n\v"]/
        DAY_NAMES = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

        # One argument as CommandLineToArgvW / the MSVCRT read it back: quoted when empty or holding
        # whitespace or a quote; backslashes are doubled only before a quote (or the closing quote)
        def self.quote(arg)
          return arg if !arg.empty? && !arg.match?(NEEDS_QUOTES)

          body = arg.gsub(/(\\*)"/) { "#{Regexp.last_match(1).to_s * 2}\\\"" }.sub(/(\\+)\z/) { Regexp.last_match(1).to_s * 2 }
          "\"#{body}\""
        end

        def self.join(args) = args.map { |arg| quote(arg) }.join(' ')

        def initialize(runner: CommandRunner.new, clock: Time)
          @runner = runner
          @clock = clock
        end

        def label = 'Task Scheduler'

        def task_name(os_id) = "#{FOLDER}#{checked_os_id(os_id)}"

        # The task XML (a UTF-8 String; install writes it as UTF-16LE with a BOM)
        def task_xml(schedule)
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
          file.write("﻿#{task_xml(schedule)}".encode(Encoding::UTF_16LE))
          file.close
          result = schtasks('/Create', '/TN', task_name(os_id), '/XML', file.path.to_s, '/F')
          return true if result.success?

          raise Error, "Task Scheduler could not create #{os_id}: #{Flows.printable(result.stderr.strip)}"
        ensure
          file&.close!
        end

        # True when the task was deleted, false when it was already gone; asks first because
        # schtasks words "not found" in the system language
        def remove(os_id)
          return false unless present?(os_id)

          result = schtasks('/Delete', '/TN', task_name(os_id), '/F')
          return true if result.success?

          raise Error, "Task Scheduler could not delete #{os_id}: #{Flows.printable(result.stderr.strip)}"
        end

        def present?(os_id) = schtasks('/Query', '/TN', task_name(os_id)).success?

        private

        def schtasks(*args) = @runner.call(SCHTASKS, *args)

        def checked_os_id(os_id)
          return os_id if os_id.is_a?(String) && (match = OS_ID.match(os_id)) && Flows.valid_name?(match[1])

          raise Error, "Invalid os_id #{Flows.printable(os_id.inspect)}: not a flow schedule"
        end

        def escape(value) = value.to_s.gsub(/[&<>"']/, ESCAPES)

        def text(name, value) = ["<#{name}>#{escape(value)}</#{name}>"]

        # tag may carry fixed attributes ('Principal id="Author"'); the closing tag is its first word
        def element(tag, children) = ["<#{tag}>", *indent(children.flatten), "</#{tag.split.first}>"]

        def indent(lines) = lines.map { |line| "  #{line}" }

        # Local time without an offset, from today: Task Scheduler then follows the PC's clock and DST
        def trigger(schedule)
          start = format('%<date>sT%<hour>02d:%<minute>02d:00', date: @clock.now.strftime('%Y-%m-%d'), hour: schedule.hour, minute: schedule.minute)
          every = schedule.every
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
