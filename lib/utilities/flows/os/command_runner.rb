# frozen_string_literal: true

require 'open3'

module RubyRaider
  module Flows
    module Os
      # Runs an OS scheduler command (launchctl, schtasks, systemctl, crontab) with no shell. Adapters
      # take one, so tests pass a double and never touch the real scheduler.
      class CommandRunner
        MISSING = 127

        # What a command printed and how it exited
        class Result
          attr_reader :stdout, :stderr, :exitstatus

          def initialize(stdout:, stderr:, exitstatus:)
            @stdout = stdout
            @stderr = stderr
            @exitstatus = exitstatus
            freeze
          end

          def success? = exitstatus.zero?
        end

        # [command, command] as the first item keeps even a lone string out of a shell
        def call(*argv, stdin_data: nil)
          command = argv.first.to_s
          stdout, stderr, status = Open3.capture3([command, command], *argv.drop(1).map(&:to_s), stdin_data: stdin_data.to_s)
          Result.new(stdout: stdout, stderr: stderr, exitstatus: status.exitstatus || (128 + status.termsig.to_i))
        rescue SystemCallError => e
          Result.new(stdout: '', stderr: "Could not run #{command}: #{e.message}", exitstatus: MISSING)
        end
      end
    end
  end
end
