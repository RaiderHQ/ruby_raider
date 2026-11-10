# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require_relative 'command_runner'
require_relative '../base'

module RubyRaider
  module Schedules
    module Os
      # Linux: a oneshot service and a persistent timer per schedule in the user's systemd folder, enabled
      # with systemctl --user. Words in ExecStart= and Environment= are double-quoted with C escapes; every
      # value has % doubled (specifiers) and ExecStart= also has $ doubled (variable expansion).
      # :reek:TooManyConstants { max_constants: 5 } -- the tool, NOFOLLOW, the escapes, the calendar days, the path rule
      class Systemd
        SYSTEMCTL = 'systemctl'
        NOFOLLOW = defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0
        QUOTED = { '\\' => '\\\\', '"' => '\\"', '%' => '%%' }.freeze
        CALENDAR = { 'hour' => '', 'day' => '', 'weekday' => 'Mon..Fri ' }.freeze
        # The unit parser strips whitespace at the ends of a value and reads a trailing backslash as "continued"
        UNSAFE_PATH = /\s\z|\\\z/

        # kind: the Kind whose units this adapter writes and removes
        def initialize(kind:, runner: CommandRunner.new, home: Dir.home, config_home: ENV.fetch('XDG_CONFIG_HOME', nil))
          @kind = kind
          @runner = runner
          @home = home
          @config_home = config_home
        end

        def label = 'systemd'

        def missed_runs_note = nil

        def service(schedule)
          env = schedule.env.map { |key, value| "Environment=#{quote("#{key}=#{value}")}" }
          exec = schedule.argv.map { |arg| quote(arg.gsub('$', '$$')) }.join(' ')
          log = specifiers(schedule.log_path)
          <<~UNIT
            [Unit]
            Description=#{@kind.service_description(schedule.name)}

            [Service]
            Type=oneshot
            WorkingDirectory=#{specifiers(schedule.working_directory)}
            #{env.join("\n")}
            ExecStart=#{exec}
            StandardOutput=append:#{log}
            StandardError=append:#{log}
          UNIT
        end

        # Local time; Persistent= runs a missed time once the user manager is back
        def timer(schedule)
          every = schedule.every
          day = CALENDAR.fetch(every) { "#{schedule.on.to_s.capitalize} " }
          hour = every == 'hour' ? '*' : format('%02d', schedule.hour)
          <<~UNIT
            [Unit]
            Description=#{@kind.timer_description(schedule.name)}

            [Timer]
            OnCalendar=#{day}*-*-* #{hour}:#{format('%02d', schedule.minute)}:00
            Persistent=true

            [Install]
            WantedBy=timers.target
          UNIT
        end

        def unit_path(os_id, unit) = File.join(units_dir, "#{checked_os_id(os_id)}.#{unit}")

        # Writes both units (temp files renamed into place), reloads and enables the timer; a failure leaves no unit behind
        def install(schedule)
          os_id = schedule.os_id
          [schedule.working_directory, schedule.log_path].each { |path| checked_path(path) }
          write({ unit_path(os_id, 'service') => service(schedule), unit_path(os_id, 'timer') => timer(schedule) })
          failure = [systemctl('daemon-reload'), systemctl('enable', '--now', "#{os_id}.timer")].find { |result| !result.success? }
          return true unless failure

          message = "systemd could not enable #{os_id}: #{Schedules.printable(failure.stderr.strip)}"
          raise Error, "#{message}#{discard(os_id)}"
        end

        # True when a unit file was removed, false when it was already gone
        def remove(os_id)
          paths = %w[service timer].map { |unit| unit_path(os_id, unit) }
          systemctl('disable', '--now', "#{os_id}.timer")
          removed = paths.map { |path| unlink(path) }.any?
          reload = systemctl('daemon-reload')
          raise Error, "systemd could not reload after removing #{os_id}: #{Schedules.printable(reload.stderr.strip)}" unless reload.success?

          removed
        end

        def present?(os_id) = systemctl('is-enabled', "#{checked_os_id(os_id)}.timer").success?

        # True when a unit file for the schedule is on disk (no user manager needed)
        def unit_files?(os_id) = %w[service timer].any? { |unit| File.exist?(unit_path(os_id, unit)) }

        # True when the user's systemd manager answers
        def usable? = systemctl('show-environment').success?

        private

        def systemctl(*args) = @runner.call(SYSTEMCTL, '--user', *args)

        def units_dir
          config = @config_home
          base = config.is_a?(String) && File.absolute_path?(config) ? config : File.join(@home, '.config')
          File.join(base, 'systemd', 'user')
        end

        def checked_os_id(os_id)
          return os_id if @kind.name_in(os_id)

          raise Error, "Invalid os_id #{Schedules.printable(os_id.inspect)}: #{@kind.not_ours}"
        end

        def checked_path(path)
          raise Error, "systemd can not use the path #{Schedules.printable(path.inspect)}: it ends in whitespace or a backslash" if UNSAFE_PATH.match?(path)
        end

        # A word systemd gives back exactly: double quotes, \\ and \" escapes, %% for %
        def quote(text) = %("#{text.gsub(/[\\"%]/, QUOTED)}")

        # A raw path value: only specifiers apply
        def specifiers(text) = text.gsub('%', '%%')

        # True when the file was there; a unit that stays behind is an error, not "already gone"
        def unlink(path)
          File.unlink(path)
          true
        rescue Errno::ENOENT
          false
        rescue SystemCallError => e
          raise Error, "Could not remove #{path}: #{e.message}"
        end

        # Disables the timer, removes both units and reloads; returns what to add to the error when that fails too
        def discard(os_id)
          systemctl('disable', "#{os_id}.timer")
          %w[service timer].each { |unit| unlink(unit_path(os_id, unit)) }
          reload = systemctl('daemon-reload')
          reload.success? ? '' : "; also: reload failed: #{Schedules.printable(reload.stderr.strip)}"
        rescue Error => e
          "; also: #{e.message}"
        end

        # Every temp file is written before any unit is replaced, so a failed write changes nothing
        def write(texts)
          temps = {}
          texts.each { |path, text| temps[path] = temp_file(path, text) }
          temps.each { |path, temp| File.rename(temp, path) }
        rescue SystemCallError => e
          raise Error, "Could not write the systemd units in #{units_dir}: #{e.message}"
        ensure
          temps&.each_value { |temp| FileUtils.rm_f(temp) if File.exist?(temp) }
        end

        def temp_file(path, text)
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir)
          temp = File.join(dir, ".#{File.basename(path)}.#{SecureRandom.hex(6)}.tmp")
          File.open(temp, File::WRONLY | File::CREAT | File::EXCL | NOFOLLOW, 0o644) do |file|
            file.write(text)
            file.flush
            file.fsync
            file.chmod(0o644)
          end
          temp
        rescue SystemCallError
          FileUtils.rm_f(temp) if temp && File.file?(temp)
          raise
        end
      end
    end
  end
end
