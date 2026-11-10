# frozen_string_literal: true

require 'English'

module RubyRaider
  module Schedules
    # Runs one rspec (or flow) process with an argv array and no shell, under the project's own bundle rather
    # than the one raider runs in, and stops it the way a person would: with exactly one INT.
    #
    # rspec stops gracefully on its first INT (it finishes the example, prints the summary and runs at_exit
    # hooks, where raider_reporter writes run.json) and force-quits on a second one. The child stays in the
    # terminal's process group (it can read the terminal, and a closed terminal ends it), so a Ctrl-C typed
    # there already reached it. Hence:
    # - TERM is always passed on as one INT;
    # - INT is passed on only with forward_int (true when the INT can't have come from the terminal, e.g.
    #   stdin is not a TTY); otherwise the child is taken to have had it;
    # - a signal before the child exists is passed on once it does;
    # - never more than one INT per run. On Windows the console already sent Ctrl-C to the child.
    module Spawn
      # [exit status (nil when it could not start or died of a signal), true when INT or TERM stopped it]
      def self.call(env, argv, chdir, forward_int: true)
        state = { pid: nil, stopped: false, interrupted: false }
        code = run(env, argv, chdir, state, forward_int)
        [code, state[:stopped] == true]
      end

      # The exit status, with the traps set from before the spawn (so a stop in between is not lost) to the end
      def self.run(env, argv, chdir, state, forward_int)
        previous = %w[INT TERM].to_h { |signal| [signal, trap(signal) { stop(state, signal, forward_int) }] }
        wait = lambda do
          state[:pid] = Process.spawn(env, *argv, chdir: chdir)
          interrupt(state) if state[:stopped]
          Process.wait(state[:pid])
          $CHILD_STATUS.exitstatus
        end
        defined?(Bundler) ? Bundler.with_unbundled_env(&wait) : wait.call
      rescue SystemCallError => e
        warn("Could not start #{argv.first}: #{e.message}")
        nil
      ensure
        previous&.each { |signal, handler| trap(signal, handler || 'DEFAULT') }
      end

      # Called from the trap: marks the run stopped and passes the signal on as INT when the child needs it
      def self.stop(state, signal, forward_int)
        state[:stopped] = true
        return unless state[:pid] # passed on right after the spawn

        # A terminal Ctrl-C reached the child too: count it as the child's one INT
        return state[:interrupted] = true if signal == 'INT' && !forward_int

        interrupt(state)
      end

      # INT, at most once per run
      def self.interrupt(state)
        return if state[:interrupted] || Gem.win_platform?

        state[:interrupted] = true
        Process.kill('INT', state[:pid])
      rescue SystemCallError
        nil
      end
    end
  end
end
