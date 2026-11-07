# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'
require_relative 'role_finder'

# Reports to an optional observer. A failing observer is switched off, never the test.
module Raider
  class << self
    # Calls hook on the observer when it answers it; the block builds the details lazily.
    # A broken observer (even a NotImplementedError or SystemStackError) is switched off, never the test.
    def report(hook, *args, **details)
      watcher = observer
      return unless watcher.respond_to?(hook)

      Observer.guarded { watcher.public_send(hook, *args, **(block_given? ? yield : details)) }
    rescue StandardError, ScriptError, SystemStackError => e
      Observer.stop(watcher, e)
    end
  end

  # Element actions as events, and the locator stamped on every found element.
  module Observer
    LIB_DIR = File.expand_path(__dir__)
    GUARD_KEY = :raider_in_observer
    MESSAGE_LIMIT = 200

    STRATEGIES = {
      'css_selector' => 'css', 'css selector' => 'css', 'class' => 'class_name', 'class name' => 'class_name',
      'link' => 'link_text', 'link text' => 'link_text', 'partial_link' => 'partial_link_text',
      'partial link text' => 'partial_link_text', 'tag name' => 'tag_name'
    }.freeze

    # One reported action. :reek:TooManyInstanceVariables { max_instance_variables: 6 } -- the event's whole state
    class Run
      def initialize(element, action, args)
        @element = element
        @action = action
        @args = args
        @retries = 0
        @token = Raider.report(:action_started) { Observer.started(element, action, args) }
        @started = Observer.clock
      end

      def ready(retries)
        @retries = retries
        Raider.report(:action_ready, @token) { { element: @element } } unless @token.nil?
      end

      def finish(error)
        Raider.report(:action_finished, @token) { finished(error) } unless @token.nil?
      end

      private

      def finished(error)
        @retries = error.retries if error.is_a?(NotActionable)
        { status: error ? :failed : :passed, waited_ms: Observer.millis(@started), retries: @retries,
          error: error, element: @element }
      end
    end

    class << self
      # Yields a Run (nil without an observer); reports the outcome and re-raises whatever the body raised.
      def emit_action(element, action, args = nil)
        return yield(nil) if Raider.observer.nil? || Thread.current[GUARD_KEY]

        run = Run.new(element, action, args)
        begin
          result = yield(run)
        rescue Exception => e # rubocop:disable Lint/RescueException -- reports and re-raises, never swallows
          run.finish(e)
          raise
        end
        run.finish(nil)
        result
      end

      def started(element, action, args)
        stamp = locator_of(element)
        { action: action, locator: stamp&.slice(:strategy, :selector), within: stamp ? stamp[:within] : [], args: args }
      end

      def locator_of(element)
        element.instance_variable_get(:@raider_locator)
      end

      def stamp(element, args, parent)
        attach(element, frozen_stamp(args, parent))
      end

      # One stamp per find, shared by every element it returned.
      def stamp_all(elements, args, parent)
        return elements if elements.empty?

        shared = frozen_stamp(args, parent)
        elements.each { |element| attach(element, shared) }
      end

      # Marks the observer as busy so an action taken inside a hook is not reported again.
      def guarded
        previous = Thread.current[GUARD_KEY]
        Thread.current[GUARD_KEY] = true
        yield
      ensure
        Thread.current[GUARD_KEY] = previous
      end

      # Prints one line and clears the observer, unless the observer was replaced meanwhile.
      def stop(watcher, error)
        $stderr.puts "[raider] observer stopped: #{summary(error)}" # rubocop:disable Style/StderrPuts -- must not be silenced by -W0
        Raider.observer = nil if Raider.observer.equal?(watcher)
      end

      def millis(started)
        ((clock - started) * 1000).round
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      private

      def attach(element, stamp)
        return element if !element.is_a?(Selenium::WebDriver::Element) || element.frozen?

        element.instance_variable_set(:@raider_locator, stamp)
        element
      end

      def frozen_stamp(args, parent)
        stamp = describe(args, parent)
        stamp[:within].each(&:freeze).freeze
        stamp.freeze
      end

      # The class and the first line of the message; never raises, whatever #message does.
      def summary(error)
        line = error.message.to_s.lines.first.to_s.chomp
        "#{error.class}: #{line[0, MESSAGE_LIMIT]}"
      rescue StandardError, ScriptError, SystemStackError
        error.class.to_s
      end

      def describe(args, parent)
        how, what = args.size == 1 && args.first.is_a?(Hash) ? args.first.first : args
        strategy = how.to_s
        { strategy: STRATEGIES.fetch(strategy, strategy), selector: selector(strategy, what, args), within: chain(parent) }
      end

      def selector(strategy, what, args)
        return role_text(args) if strategy == 'role'

        (what.is_a?(Array) ? what.first : what).to_s
      end

      def role_text(args)
        role, options = RoleFinder.parse(args)
        [role, *options.map { |key, value| "#{key}: #{value}" }].join(', ')
      end

      def chain(parent)
        found = parent.is_a?(Selenium::WebDriver::Element) ? locator_of(parent) : nil
        found ? [*found[:within], found.slice(:strategy, :selector)] : []
      end
    end
  end
end
