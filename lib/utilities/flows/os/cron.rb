# frozen_string_literal: true

require 'shellwords'
require_relative 'command_runner'
require_relative '../schedule'

module RubyRaider
  module Flows
    module Os
      # Linux without a systemd user manager: one tagged block per schedule in the user's crontab, read with
      # `crontab -l` and written back with `crontab -`. Every value goes through Shellwords.escape, which also
      # escapes % as \% (cron would turn a bare % into a newline). Lines that are not ours keep every byte.
      class Cron
        CRONTAB = 'crontab'
        TAG = '# raider-flow '
        OS_ID = /\A#{Regexp.escape(Schedule::OS_ID_PREFIX)}\.[0-9a-f]{10}\.([a-z0-9_]{1,60})\z/

        def initialize(runner: CommandRunner.new)
          @runner = runner
        end

        def label = 'cron'

        def missed_runs_note = '(cron: missed runs are skipped)'

        # Minute hour day-of-month month day-of-week (the system time zone), then the command for /bin/sh
        def line(schedule)
          ruby = schedule.ruby
          raise Error, "cron can not run ruby from #{Flows.printable(ruby)}: env would read the = as a variable" if ruby.include?('=')

          env = schedule.env.map { |key, value| "#{key}=#{value}" }
          command = ['cd', escape(schedule.working_directory), '&&', '/usr/bin/env', *[*env, *schedule.argv].map { |word| escape(word) },
                     '>>', escape(schedule.log_path), '2>&1']
          "#{fields(schedule)} #{command.join(' ')}"
        end

        # Our block goes first: above any SHELL=, CRON_TZ= or MAILTO= line, and with no byte of the rest changed
        def install(schedule)
          os_id = schedule.os_id
          rest, = without(read, os_id)
          save("#{TAG}#{os_id}\n#{line(schedule)}\n#{rest}")
          true
        end

        # True when our block was there and is gone, false when it was already gone
        def remove(os_id)
          tag = checked_os_id(os_id)
          rest, found = without(read, tag)
          save(rest) if found
          found
        end

        def present?(os_id)
          tag = checked_os_id(os_id)
          without(read, tag).last
        end

        private

        def fields(schedule)
          minute = schedule.minute
          return "#{minute} * * * *" if schedule.every == 'hour'

          day = case schedule.every
                when 'weekday' then '1-5'
                when 'week' then weekday(schedule.on.to_s).to_s
                else '*'
                end
          "#{minute} #{schedule.hour} * * #{day}"
        end

        # cron counts Sunday as 0
        def weekday(day)
          index = Schedule::DAYS.index(day)
          raise Error, "Invalid day #{day.inspect}" unless index

          (index + 1) % 7
        end

        def escape(word) = Shellwords.escape(word)

        # The crontab without our tag line and the line after it, and whether the tag was there
        def without(table, os_id)
          lines = table.lines
          index = lines.index { |text| text.chomp == "#{TAG}#{os_id}" }
          return [table, false] unless index

          lines.slice!(index, 2)
          [lines.join, true]
        end

        def read
          result = @runner.call(CRONTAB, '-l')
          return result.stdout if result.success?

          stderr = result.stderr
          return '' if stderr.match?(/no crontab/i)

          raise Error, "cron could not read the crontab: #{Flows.printable(stderr.strip)}"
        end

        def save(table)
          result = @runner.call(CRONTAB, '-', stdin_data: table)
          raise Error, "cron could not save the crontab: #{Flows.printable(result.stderr.strip)}" unless result.success?
        end

        def checked_os_id(os_id)
          return os_id if os_id.is_a?(String) && (match = OS_ID.match(os_id)) && Flows.valid_name?(match[1])

          raise Error, "Invalid os_id #{Flows.printable(os_id.inspect)}: not a flow schedule"
        end
      end
    end
  end
end
