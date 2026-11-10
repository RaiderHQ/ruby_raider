# frozen_string_literal: true

module RubyRaider
  # The OS scheduler (launchd, Task Scheduler, systemd, cron) shared by test schedules and legacy flow
  # schedules. What differs between them is a Kind.
  module Schedules
    NAME = /\A[a-z0-9_]{1,60}\z/
    # Schedule::DAYS order, as every adapter counts it
    DAYS = %w[mon tue wed thu fri sat sun].freeze

    def self.valid_name?(name) = NAME.match?(name.to_s)

    # Text from a log or a command, safe to print: it can't move the cursor or forge lines
    def self.printable(text) = text.to_s.gsub(/[[:cntrl:]]/, '?')

    # A problem that stops a schedule or flow command; exit_code follows `raider flow run` (2 = setup failed).
    class Error < StandardError
      attr_reader :exit_code

      def initialize(message, exit_code: 2)
        super(message)
        @exit_code = exit_code
      end
    end
  end
end
