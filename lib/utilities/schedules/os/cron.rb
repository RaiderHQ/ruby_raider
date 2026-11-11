# frozen_string_literal: true

require 'shellwords'
require_relative 'command_runner'
require_relative '../base'

module RubyRaider
  module Schedules
    module Os
      # Linux without a systemd user manager: one tagged block per schedule in the user's crontab, read with
      # `crontab -l` and written back with `crontab -`. Every value goes through Shellwords.escape, which also
      # escapes % as \% (cron would turn a bare % into a newline). Lines that are not ours keep every byte.
      class Cron
        CRONTAB = 'crontab'
        # Debian's vixie cron cuts a command at MAX_COMMAND (1000) bytes without a word; stay under it
        MAX_LINE = 990

        # kind: the Kind whose entries this crontab block holds
        def initialize(kind:, runner: CommandRunner.new)
          @kind = kind
          @runner = runner
        end

        def label = 'cron'

        def missed_runs_note = '(cron: missed runs are skipped)'

        # Minute hour day-of-month month day-of-week (the system time zone), then the command for /bin/sh
        def line(schedule)
          ruby = schedule.ruby
          raise Error, "cron can not run ruby from #{Schedules.printable(ruby)}: env would read the = as a variable" if ruby.include?('=')

          env = schedule.env.map { |key, value| "#{key}=#{value}" }
          command = ['cd', escape(schedule.working_directory), '&&', '/usr/bin/env', *[*env, *schedule.argv].map { |word| escape(word) },
                     '>>', escape(schedule.log_path), '2>&1']
          "#{fields(schedule)} #{command.join(' ')}"
        end

        # Our block goes first: above any SHELL=, CRON_TZ= or MAILTO= line, and with no byte of the rest changed
        def install(schedule)
          os_id = schedule.os_id
          entry = line(schedule)
          raise Error, "cron can not run #{schedule.name}: its crontab line is #{entry.bytesize} bytes, over #{MAX_LINE}" if entry.bytesize > MAX_LINE

          rest, = without(read, os_id)
          save("#{@kind.cron_tag}#{os_id}\n#{entry}\n#{rest}")
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

        # The os_ids of this kind starting with prefix on our tag lines, sorted
        def list_ids(prefix)
          tag = @kind.cron_tag
          read.dup.force_encoding(Encoding::UTF_8).scrub.each_line.filter_map do |text|
            line = text.chomp
            id = line.delete_prefix(tag)
            id if id != line && @kind.listed?(id, prefix)
          end.uniq.sort
        end

        # True when crontab -l answers (an empty crontab counts)
        def usable?
          read
          true
        rescue Error
          false
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
          index = DAYS.index(day)
          raise Error, "Invalid day #{day.inspect}" unless index

          (index + 1) % 7
        end

        def escape(word) = Shellwords.escape(word)

        # The crontab without any of our tag lines, each with the line after it when that line is our command,
        # and whether a tag was there
        def without(table, os_id)
          tag = "#{@kind.cron_tag}#{os_id}"
          name = @kind.os_id_pattern.match(os_id).to_a[1]
          kept = []
          found = after_tag = false
          table.lines.each do |text|
            ours = text.chomp == tag || (after_tag && our_command?(text, name))
            after_tag = text.chomp == tag
            found ||= after_tag
            kept << text unless ours
          end
          [kept.join, found]
        end

        # The line under our tag runs `raider <command> run <name> --project ... --trigger schedule`
        def our_command?(text, name) = @kind.our_command?(text, name)

        def read
          result = @runner.call(CRONTAB, '-l')
          return result.stdout if result.success?

          stderr = result.stderr.scrub('?')
          return '' if stderr.match?(/no crontab/i)

          raise Error, "cron could not read the crontab: #{Schedules.printable(stderr.strip)}"
        end

        def save(table)
          result = @runner.call(CRONTAB, '-', stdin_data: table)
          raise Error, "cron could not save the crontab: #{Schedules.printable(result.stderr.strip)}" unless result.success?
        end

        def checked_os_id(os_id)
          return os_id if @kind.name_in(os_id)

          raise Error, "Invalid os_id #{Schedules.printable(os_id.inspect)}: #{@kind.not_ours}"
        end
      end
    end
  end
end
