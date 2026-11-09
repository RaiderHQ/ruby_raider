# frozen_string_literal: true

require 'open3'

module RubyRaider
  module Flows
    module Os
      # Runs an OS scheduler command (launchctl, schtasks, systemctl, crontab) with no shell. Adapters
      # take one, so tests pass a double and never touch the real scheduler.
      class CommandRunner
        MISSING = 127
        TIMED_OUT = 124

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

        # [command, command] as the first item keeps even a lone string out of a shell; env adds to the inherited
        # one. With a timeout (seconds) a command still running then is killed and fails.
        def call(*argv, stdin_data: nil, env: {}, timeout: nil)
          command = argv.first.to_s
          Open3.popen3(env, [command, command], *argv.drop(1).map(&:to_s)) do |stdin, stdout, stderr, wait|
            readers = [stdout, stderr].map { |io| reader(io) }
            feed(stdin, stdin_data)
            next timed_out(command, timeout, wait) unless wait.join(timeout)

            status = wait.value
            Result.new(stdout: readers[0].value, stderr: readers[1].value, exitstatus: status.exitstatus || (128 + status.termsig.to_i))
          end
        rescue SystemCallError => e
          Result.new(stdout: '', stderr: "Could not run #{command}: #{e.message}", exitstatus: MISSING)
        end

        private

        # Read in a thread, so a full pipe can't block the command; quiet when the pipe is closed under it
        def reader(io)
          thread = Thread.new { io.read.to_s }
          thread.report_on_exception = false
          thread
        end

        def feed(stdin, data)
          stdin.write(data.to_s)
        rescue Errno::EPIPE
          nil
        ensure
          stdin.close
        end

        def timed_out(command, timeout, wait)
          begin
            Process.kill('KILL', wait.pid)
          rescue SystemCallError
            nil
          end
          wait.join
          Result.new(stdout: '', stderr: "#{command} took longer than #{timeout} s", exitstatus: TIMED_OUT)
        end
      end
    end
  end
end
