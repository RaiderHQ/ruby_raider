# frozen_string_literal: true

require_relative 'command_runner'
require_relative 'systemd'
require_relative 'cron'

module RubyRaider
  module Flows
    module Os
      # Linux: systemd user timers when the user's systemd manager answers, cron otherwise. A schedule made over
      # ssh (no user bus, so cron) must still go when unscheduled from a desktop session, so remove and present?
      # also look in the other scheduler when it answers.
      class Linux
        def self.pick(runner = CommandRunner.new) = new(runner: runner)

        def initialize(runner: CommandRunner.new, systemd: Systemd.new(runner: runner), cron: Cron.new(runner: runner))
          # systemd is the other one only when it answers, so with cron first there is no other one
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
          removed || other_removed
        end

        # True when either scheduler has it
        def present?(os_id) = @primary.present?(os_id) || other_present?(os_id)

        private

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
