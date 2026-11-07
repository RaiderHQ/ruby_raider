# frozen_string_literal: true

require 'rspec/expectations'
require 'selenium-webdriver'
require_relative '../config'
require_relative '../errors'
require_relative '../wait'

module Raider
  module Matchers
    # Shared polling for the web-first matchers. Subclasses implement `read(subject)`,
    # `pass?(value)` and `verb`, and may override `absent_passes?`.
    class Base
      include RSpec::Matchers::Composable

      # Compound evaluation that hands each matcher the actual as is, so a block
      # actual is resolved by each matcher itself rather than nested.
      module Sequential
        private

        def evaluate(actual)
          @evaluator = RSpec::Matchers::BuiltIn::Compound::SequentialEvaluator.new(actual, matcher_1, matcher_2)
        end
      end

      # `a.and(b)` evaluated sequentially.
      class And < RSpec::Matchers::BuiltIn::Compound::And
        include Sequential

        private

        def match(_expected, actual)
          evaluate(actual)
          matcher_1_matches? && matcher_2_matches?
        end
      end

      # `a.or(b)` evaluated sequentially.
      class Or < RSpec::Matchers::BuiltIn::Compound::Or
        include Sequential

        private

        def match(_expected, actual)
          evaluate(actual)
          matcher_1_matches? || matcher_2_matches?
        end
      end

      NOT_FOUND = Object.new.freeze
      STALE_HINT = 'the element is stale; re-find it, use the block form, or a page-object element'

      # Raised inside the poll to end it at once: a raw element went stale.
      class StaleActual < StandardError; end

      # What the last poll saw, for the failure message.
      Poll = Struct.new(:actual, :subject, :value, :waited, :elapsed, :stale)

      attr_reader :expected

      def initialize(expected, wait: nil, **options)
        @expected = expected
        @wait = wait
        @options = options
        @poll = Poll.new(nil, nil, NOT_FOUND, nil, 0, false)
      end

      def matches?(actual)
        poll(actual, negated: false)
      end

      def does_not_match?(actual)
        poll(actual, negated: true)
      end

      def failure_message
        message('to')
      end

      def failure_message_when_negated
        message('not to')
      end

      def and(other)
        And.new(self, other)
      end
      alias & and

      def or(other)
        Or.new(self, other)
      end
      alias | or

      def supports_block_expectations?
        true
      end

      def description
        "#{verb} #{expected.inspect}"
      end

      def absent_passes?
        false
      end

      def resolve(actual)
        actual.is_a?(Proc) ? actual.call : actual
      end

      def read_with_zero_wait(subject, method, *args)
        return subject.public_send(method, *args) unless accepts_timeout?(subject, method)

        subject.public_send(method, *args, timeout: 0)
      end

      private

      def option(key)
        @options[key]
      end

      def polled_actual
        @poll.actual
      end

      def wait_for(_actual)
        @wait || Raider.timeout
      end

      def poll(actual, negated:)
        @poll = Poll.new(actual, nil, NOT_FOUND, wait_for(actual), 0, false)
        started = clock
        begin
          Raider::Wait.until(timeout: @poll.waited) { settled?(negated) }
          true
        rescue Raider::TimeoutError, StaleActual
          false
        ensure
          @poll.elapsed = clock - started
        end
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def settled?(negated)
        @poll.subject = resolve(@poll.actual)
        @poll.value = read(@poll.subject)
        pass?(@poll.value) != negated || throw(:not_ready)
      rescue *retried_errors => e
        @poll.value = NOT_FOUND
        gone(e, negated)
      end

      # The read found nothing: pass where absence counts, fail at once for a stale raw
      # element, and otherwise try again.
      def gone(error, negated)
        return true if negated ? negated_absent_passes? : absent_passes?

        raise_stale if error.is_a?(Selenium::WebDriver::Error::StaleElementReferenceError) && raw_element?
        throw :not_ready
      end

      def negated_absent_passes?
        false
      end

      def raw_element?
        @poll.actual.is_a?(Selenium::WebDriver::Element)
      end

      def raise_stale
        @poll.stale = true
        raise StaleActual
      end

      def retried_errors
        [Selenium::WebDriver::Error::NoSuchElementError,
         Selenium::WebDriver::Error::StaleElementReferenceError,
         Selenium::WebDriver::Error::TimeoutError, Raider::AmbiguousMatch]
      end

      def accepts_timeout?(subject, method)
        subject.method(method).parameters.any? { |_kind, name| name == :timeout }
      end

      def message(polarity)
        head = "expected #{target} #{polarity} #{description}"
        return "#{head}, but #{STALE_HINT}" if @poll.stale

        "#{head}, #{last_seen} after #{Raider::Describe.seconds(@poll.elapsed)}s"
      end

      def target
        return 'the block' if @poll.actual.is_a?(Proc)

        shown = @poll.subject || @poll.actual
        shown.respond_to?(:tag_name) ? Raider::Describe.element(shown) : shown.inspect
      end

      def last_seen
        value = @poll.value
        value.equal?(NOT_FOUND) ? 'last seen: not found' : "last seen #{show(value)}"
      end

      def show(value)
        value.inspect
      end
    end
  end
end
