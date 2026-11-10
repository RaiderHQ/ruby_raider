# frozen_string_literal: true

require_relative 'command_runner'
require_relative 'systemd'
require_relative 'cron'

module RubyRaider
  module Schedules
    module Os
      # Linux: systemd user timers when the user's systemd manager answers, cron otherwise. A schedule made over
      # ssh (no user bus, so cron) must still go when unscheduled from a desktop session, so remove and present?
      # also look in the other scheduler when it answers. The reverse (a systemd timer, unscheduled where no user
      # bus answers) can only be seen from its unit files, and can only be removed where systemctl --user works.
      class Linux
        def self.pick(runner = CommandRunner.new, kind:) = new(kind: kind, runner: runner)

        # kind: the Kind of the schedules this adapter installs and removes
        def initialize(kind:, runner: CommandRunner.new, systemd: Systemd.new(kind: kind, runner: runner), cron: Cron.new(kind: kind, runner: runner))
          @kind = kind
          # systemd is the other one only when it answers, so with cron first there is no other one
          @systemd = systemd
          @primary, @other = systemd.usable? ? [systemd, cron] : [cron, nil]
        end

        def label = @primary.label

        def missed_runs_note = @primary.missed_runs_note

        def install(schedule) = @primary.install(schedule)

        # True when either scheduler removed something
        def remove(os_id)
          removed = @primary.remove(os_id)
          other = @other
          other_removed = other&.usable? ? other.remove(os_id) : false
          refuse_stranded(os_id)
          removed || other_removed
        end

        # True when either scheduler has it, or systemd unit files are there though systemd does not answer
        def present?(os_id) = @primary.present?(os_id) || other_present?(os_id) || stranded?(os_id)

        # Both schedulers' ids plus systemd unit files (there even when systemd does not answer); only the
        # primary scheduler failing is an error
        def list_ids(prefix)
          (@primary.list_ids(prefix) + other_ids(prefix) + quietly { @systemd.list_ids(prefix) }).uniq.sort
        end

        private

        def other_ids(prefix)
          other = @other
          other&.usable? ? quietly { other.list_ids(prefix) } : []
        end

        def quietly
          yield
        rescue Error
          []
        end

        def stranded?(os_id) = @primary != @systemd && @systemd.unit_files?(os_id)

        # Raises so the schedules.yml entry stays until the timer can really go
        def refuse_stranded(os_id)
          return unless stranded?(os_id)

          raise Error, @kind.stranded(os_id.split('.').last)
        end

        # The other scheduler failing counts as not there
        def other_present?(os_id)
          other = @other
          other&.usable? ? other.present?(os_id) : false
        rescue Error
          false
        end
      end
    end
  end
end
