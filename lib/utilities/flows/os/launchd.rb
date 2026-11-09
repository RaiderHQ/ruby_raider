# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require_relative 'command_runner'
require_relative '../schedule'

module RubyRaider
  module Flows
    module Os
      # macOS: a LaunchAgent plist in ~/Library/LaunchAgents per schedule, loaded into the user's GUI
      # domain with launchctl. Every value in the plist goes through one XML escaper.
      # :reek:TooManyConstants { max_constants: 6 } -- the two tools, NOFOLLOW, the XML escapes and header, the os_id rule
      class Launchd
        LAUNCHCTL = '/bin/launchctl'
        PLUTIL = '/usr/bin/plutil'
        NOFOLLOW = defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0
        ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;' }.freeze
        HEADER = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
        XML
        OS_ID = /\A#{Regexp.escape(Schedule::OS_ID_PREFIX)}\.[0-9a-f]{10}\.([a-z0-9_]{1,60})\z/

        def initialize(runner: CommandRunner.new, home: Dir.home, uid: Process.uid)
          @runner = runner
          @home = home
          @uid = uid
        end

        def label = 'launchd'

        # The LaunchAgent plist for the schedule (local time, no RunAtLoad)
        def plist(schedule)
          path = schedule.log_path
          entries = [
            ['Label', string(schedule.os_id)],
            ['ProgramArguments', array(schedule.argv.map { |arg| string(arg) })],
            ['WorkingDirectory', string(schedule.working_directory)],
            ['StandardOutPath', string(path)],
            ['StandardErrorPath', string(path)],
            ['EnvironmentVariables', dict(schedule.env.map { |key, value| [key, string(value)] })],
            ['StartCalendarInterval', calendar(schedule)]
          ]
          "#{HEADER}#{dict(entries).join("\n")}\n</plist>\n"
        end

        def plist_path(os_id) = File.join(agents_dir, "#{checked_os_id(os_id)}.plist")

        # Writes the plist (linted before it replaces anything), then reloads the service
        def install(schedule)
          os_id = schedule.os_id
          path = plist_path(os_id)
          write(path, plist(schedule))
          launchctl('bootout', service(os_id))
          result = launchctl('bootstrap', domain, path)
          return true if result.success?

          raise Error, "launchd could not load #{os_id}: #{Flows.printable(result.stderr.strip)}#{discard(path)}"
        end

        # True when a plist or a loaded service was removed, false when it was already gone
        def remove(os_id)
          path = plist_path(os_id)
          unloaded = launchctl('bootout', service(os_id)).success?
          unlink(path) || unloaded
        end

        def present?(os_id) = launchctl('print', service(checked_os_id(os_id))).success?

        private

        def launchctl(*args) = @runner.call(LAUNCHCTL, *args)

        def domain = "gui/#{@uid}"

        def service(os_id) = "#{domain}/#{os_id}"

        # True when the plist was there; a plist that stays behind is an error, not "already gone"
        def unlink(path)
          File.unlink(path)
          true
        rescue Errno::ENOENT
          false
        rescue SystemCallError => e
          raise Error, "Could not remove #{path}: #{e.message}"
        end

        def agents_dir = File.join(@home, 'Library', 'LaunchAgents')

        def checked_os_id(os_id)
          return os_id if os_id.is_a?(String) && (match = OS_ID.match(os_id)) && Flows.valid_name?(match[1])

          raise Error, "Invalid os_id #{Flows.printable(os_id.inspect)}: not a flow schedule"
        end

        def escape(text) = text.to_s.gsub(/[&<>"']/, ESCAPES)

        def string(text) = ["<string>#{escape(text)}</string>"]

        def integer(number) = ["<integer>#{Integer(number)}</integer>"]

        def array(items) = ['<array>', *indent(items.flatten), '</array>']

        def dict(pairs)
          body = pairs.flat_map { |key, value| ["<key>#{escape(key)}</key>", *value] }
          ['<dict>', *indent(body), '</dict>']
        end

        def indent(lines) = lines.map { |line| "\t#{line}" }

        # Schedule::DAYS runs mon..sun
        def calendar(schedule)
          time = [['Hour', integer(schedule.hour)], ['Minute', integer(schedule.minute)]]
          case schedule.every
          when 'hour' then dict([['Minute', integer(schedule.minute)]])
          when 'day' then dict(time)
          else
            days = schedule.days.map { |day| dict([['Weekday', integer(weekday(day))], *time]) }
            schedule.every == 'week' ? days.first : array(days)
          end
        end

        # launchd counts Sunday as 0
        def weekday(day)
          index = Schedule::DAYS.index(day)
          raise Error, "Invalid day #{day.inspect}" unless index

          (index + 1) % 7
        end

        # Removes the plist a failed bootstrap left; returns what to add to the error when it stays behind
        def discard(path)
          unlink(path)
          ''
        rescue Error => e
          "; also: #{e.message}"
        end

        # Temp file in the same folder, checked with plutil, then renamed over the old plist
        def write(path, text)
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir)
          temp = File.join(dir, ".#{File.basename(path)}.#{SecureRandom.hex(6)}.tmp")
          File.open(temp, File::WRONLY | File::CREAT | File::EXCL | NOFOLLOW, 0o644) do |file|
            file.write(text)
            file.flush
            file.fsync
            file.chmod(0o644)
          end
          lint = @runner.call(PLUTIL, '-lint', temp)
          raise Error, "launchd plist for #{File.basename(path)} is invalid: #{Flows.printable("#{lint.stdout} #{lint.stderr}".strip)}" unless lint.success?

          File.rename(temp, path)
        rescue SystemCallError => e
          raise Error, "Could not write #{path}: #{e.message}"
        ensure
          FileUtils.rm_f(temp) if temp && File.exist?(temp)
        end
      end
    end
  end
end
