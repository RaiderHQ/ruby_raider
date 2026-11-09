# frozen_string_literal: true

require 'English'
require 'securerandom'
require 'time'
require_relative 'project'
require_relative 'run_log'
require_relative 'notifier'

module RubyRaider
  module Flows
    # `raider flow run`: a thin wrapper around `bundle exec rspec flows/<name>_flow.rb`. The flow's own
    # flows/support/run.rb records the run; this sets its env, retries the whole flow and maps the
    # recorded status to the exit code.
    # :reek:TooManyInstanceVariables { max_instance_variables: 6 } -- the project, injected collaborators and the last run line
    class Runner
      EXIT_CODES = { 'completed' => 0, 'failed' => 1, 'setup_error' => 2, 'busy' => 3 }.freeze
      INPUT = /\A[a-z][a-z0-9_]{0,39}\z/
      INPUT_RULE = 'use name=value, the name 1 to 40 of a-z, 0-9 and _ starting with a letter'
      TRIGGERS = %w[manual schedule desktop].freeze
      RETRY_WAIT = 30

      class << self
        # True once INT or TERM stopped the last spawned run: no retry after that
        attr_accessor :stopped
      end

      # Runs argv with no shell, under the project's own bundle rather than the one raider runs in.
      # The flow stays in the terminal's process group (it can read the terminal, and a closed terminal
      # ends it). Its flows/support/run.rb turns the first INT into an Interrupt that ends the step and
      # still records the run, and ignores the rest. nil when it could not start: no log line, so exit 2.
      def self.spawn(env, argv, chdir)
        self.stopped = false
        pid = nil
        forwarded = false
        forward = lambda do
          next if pid.nil? || forwarded || Gem.win_platform? # the Windows console already sent Ctrl-C to the flow

          forwarded = true
          interrupt(pid)
        end
        # Before spawning, so a Ctrl-C in between is not lost
        previous = %w[INT TERM].to_h do |signal|
          [signal, trap(signal) do
            self.stopped = true
            forward.call
          end]
        end
        run = lambda do
          pid = Process.spawn(env, *argv, chdir: chdir)
          forward.call if stopped
          Process.wait(pid)
          $CHILD_STATUS.exitstatus
        end
        defined?(Bundler) ? Bundler.with_unbundled_env(&run) : run.call
      rescue SystemCallError => e
        warn("Could not start #{argv.first}: #{e.message}")
        nil
      ensure
        previous&.each { |signal, handler| trap(signal, handler || 'DEFAULT') }
      end

      # INT, sent once: from a terminal the flow already has its own, which it ignores as a repeat
      def self.interrupt(pid)
        Process.kill('INT', pid)
      rescue SystemCallError
        nil
      end

      # notifier: nil makes a Notifier only when a run with notify: true needs one
      def initialize(project, out: $stdout, spawner: Runner.method(:spawn), sleeper: ->(seconds) { sleep(seconds) }, notifier: nil)
        @project = project
        @out = out
        @spawner = spawner
        @sleeper = sleeper
        @notifier = notifier
        @last_line = nil
      end

      # Returns the exit code: 0 completed, 1 a step failed, 2 setup failed, 3 already running.
      # notify: true sends one desktop notification when the run ends in neither completed nor busy.
      def run(name, headed: false, retries: 0, inputs: [], trigger: 'manual', notify: false)
        @project.flow_file(name)
        raise Error, 'Flows are not set up in this project: run raider flow init' unless @project.set_up?

        options = { headed: headed, inputs: input_env(inputs), trigger: checked_trigger(trigger) }
        attempts = checked_retries(retries) + 1
        status = attempt_runs(name, attempts, options)
        # Not after a stop: whoever pressed Ctrl-C already knows
        notify_failure(name, status) if notify && !Runner.stopped && !%w[completed busy].include?(status)
        EXIT_CODES.fetch(status, 2)
      end

      private

      def attempt_runs(name, attempts, options)
        (1..attempts).each do |attempt|
          status = attempt_run(name, attempt, options)
          return stopped(name, status) if Runner.stopped
          return status if %w[completed busy].include?(status) || attempt == attempts

          @out.puts("Retrying in #{RETRY_WAIT} s (attempt #{attempt + 1} of #{attempts})")
          @sleeper.call(RETRY_WAIT)
        end
        'setup_error'
      end

      # The notifier never raises, so a notification can't change the exit code
      def notify_failure(name, status)
        message = if status == 'failed'
                    "Failed at #{failed_step(@last_line&.fetch('failed_step', nil))}"
                  else
                    "Could not start: see .raider/flows/#{name}/scheduler.log"
                  end
        (@notifier ||= Notifier.new).notify("Ruby Raider flow #{name}", message)
      end

      def stopped(name, status)
        @out.puts("Flow #{name} was stopped: no retry")
        status
      end

      def attempt_run(name, attempt, options)
        run_id = SecureRandom.hex(8)
        # The literal name-built path ([a-z0-9_] only), not the realpath flow_file checked
        argv = ['bundle', 'exec', 'rspec', "flows/#{name}_flow.rb", '--tag', 'flow']
        code = @spawner.call(run_env(name, attempt, run_id, options), argv, @project.root)
        line = RunLog.new(@project, name).find(run_id)
        @last_line = line
        report(name, line, code)
        line ? line['status'].to_s : 'setup_error'
      end

      # Every RAIDER_FLOW_* and RAIDER_INPUT_* is set (or unset) here, so a value left in the shell never leaks into a run
      def run_env(name, attempt, run_id, options)
        headed = options[:headed]
        stale_inputs = ENV.keys.grep(/\ARAIDER_INPUT_/).to_h { |key| [key, nil] }
        stale_inputs.merge(
          'BUNDLE_GEMFILE' => @project.path('Gemfile'),
          'RAIDER_FLOW_NAME' => name,
          'RAIDER_FLOW_ATTEMPT' => attempt.to_s,
          'RAIDER_FLOW_TRIGGER' => options[:trigger],
          'RAIDER_FLOW_RUN_ID' => run_id,
          'RAIDER_FLOW_HEADED' => headed ? '1' : nil,
          'HEADLESS' => headed ? nil : 'true',
          'RETRY_COUNT' => '0'
        ).merge(options[:inputs])
      end

      # name=value pairs; values reach the flow only through RAIDER_INPUT_<NAME>, never argv
      def input_env(inputs)
        Array(inputs).to_h do |pair|
          key, value = pair.to_s.split('=', 2)
          raise Error, "Invalid input #{key.to_s.inspect}: #{INPUT_RULE}" unless value && INPUT.match?(key.to_s)
          raise Error, "Invalid input #{key.inspect}: the value contains a NUL byte" if value.include?("\0")

          ["RAIDER_INPUT_#{key.to_s.upcase}", value]
        end
      end

      def checked_trigger(trigger)
        return trigger if TRIGGERS.include?(trigger)

        raise Error, "Invalid trigger #{trigger.inspect}: use #{TRIGGERS.join(', ')}"
      end

      def checked_retries(retries)
        return retries if retries.is_a?(Integer) && retries.between?(0, 3)

        raise Error, "Invalid retries #{retries.inspect}: use 0 to 3"
      end

      def report(name, line, code)
        return @out.puts("Flow #{name} did not record a run (exit #{code || 'none'}): see the output above") unless line

        @out.puts("Flow #{name} #{Flows.printable(outcome(line))}")
        results = line['results_dir']
        @out.puts("Results: #{Flows.printable(results)}") if results.is_a?(String) && File.directory?(@project.path(results))
      end

      def outcome(line)
        case line['status']
        when 'completed' then "completed in #{duration(line)} s"
        when 'failed' then "failed at #{failed_step(line['failed_step'])}"
        when 'busy' then 'is already running'
        else 'could not start: see the output above'
        end
      end

      def failed_step(step)
        step = {} unless step.is_a?(Hash)
        number = step['number']
        where = number ? "step #{number}" : "line #{step['line'] || '?'}"
        title = step['title']
        title ? "#{where} (#{title})" : where
      end

      def duration(line)
        (Time.iso8601(line['finished_at'].to_s) - Time.iso8601(line['started_at'].to_s)).round(1)
      rescue ArgumentError
        '?'
      end
    end
  end
end
