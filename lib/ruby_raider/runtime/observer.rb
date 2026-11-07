# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'
require_relative 'role_finder'

# Reports to an optional observer. A failing observer is switched off, never the test.
module Raider
  class << self
    # Calls hook on the observer when it answers it; the block builds the details lazily.
    def report(hook, *args, **details)
      watcher = observer
      return unless watcher.respond_to?(hook)

      watcher.public_send(hook, *args, **(block_given? ? yield : details))
    rescue StandardError => e
      $stderr.puts "[raider] observer stopped: #{e.class}: #{e.message}" # rubocop:disable Style/StderrPuts -- must not be silenced by -W0
      self.observer = nil
    end
  end

  # Element actions as events, and the locator stamped on every found element.
  module Observer
    LIB_DIR = File.expand_path(__dir__)

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
        @started = Observer.clock
        @token = Raider.report(:action_started) { Observer.started(element, action, args) }
      end

      def ready(retries)
        @retries = retries
        Raider.report(:action_ready, @token) { { element: @element } }
      end

      def finish(error)
        Raider.report(:action_finished, @token) { finished(error) }
      end

      private

      def finished(error)
        { status: error ? :failed : :passed, waited_ms: Observer.millis(@started), retries: @retries,
          error: error, element: @element }
      end
    end

    class << self
      # Yields a Run (nil without an observer); reports the outcome and re-raises whatever the body raised.
      def emit_action(element, action, args = nil)
        return yield(nil) unless Raider.observer

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
        return element unless element.is_a?(Selenium::WebDriver::Element)

        element.instance_variable_set(:@raider_locator, describe(args, parent))
        element
      end

      def stamp_all(elements, args, parent)
        elements.each { |element| stamp(element, args, parent) }
      end

      def millis(started)
        ((clock - started) * 1000).round
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      private

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
