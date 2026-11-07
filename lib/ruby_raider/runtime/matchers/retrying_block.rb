# frozen_string_literal: true

require 'rspec/expectations'
require 'selenium-webdriver'
require_relative '../config'
require_relative '../errors'
require_relative '../wait'
require_relative 'base'

module Raider
  module Matchers
    # Prepended to RSpec's BlockExpectationTarget: `expect { value }.to eq(x)` polls the
    # block until the value matches. Matchers that handle blocks themselves (Raider's,
    # raise_error, change, output, yield_*) keep stock semantics and one evaluation.
    # A polled block is re-run on every poll, so side effects in it repeat.
    module RetryingBlock
      LOOKUP_ERRORS = [Selenium::WebDriver::Error::NoSuchElementError,
                       Selenium::WebDriver::Error::StaleElementReferenceError,
                       Raider::AmbiguousMatch].freeze

      # One evaluation of the block and the check; remembers what it saw.
      class Attempt
        attr_reader :value, :error

        def initialize(block, check)
          @block = block
          @check = check
          @value = Base::NOT_FOUND
        end

        def read?
          !@value.equal?(Base::NOT_FOUND)
        end

        def pass?
          @value = Raider::Wait.immediately { @block.call }
          @check.call(@value)
        rescue *LOOKUP_ERRORS => e
          @error = e
          false
        end
      end

      def to(matcher = nil, message = nil, &)
        return super if stock?(matcher)

        settle(matcher, message, :to, false, &)
      end

      def not_to(matcher = nil, message = nil, &)
        return super if stock?(matcher)

        settle(matcher, message, :not_to, true, &)
      end

      def to_not(...)
        not_to(...)
      end

      private

      def stock?(matcher)
        matcher.nil? || matcher.is_a?(Raider::Matchers::Base) ||
          (matcher.respond_to?(:supports_block_expectations?) && matcher.supports_block_expectations?)
      end

      def check(matcher, negated)
        return matcher.method(:matches?) unless negated
        return matcher.method(:does_not_match?) if matcher.respond_to?(:does_not_match?)

        ->(value) { !matcher.matches?(value) }
      end

      def settle(matcher, message, polarity, negated, &)
        attempt = Attempt.new(target, check(matcher, negated))
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Raider::Wait.until(timeout: Raider.timeout) { attempt.pass? || throw(:not_ready) }
        true
      rescue Raider::TimeoutError
        waited = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        give_up(attempt, [matcher, message], polarity, waited, &)
      end

      def give_up(attempt, arguments, polarity, waited, &)
        raise attempt.error unless attempt.read?

        RSpec::Expectations::ExpectationTarget.for(attempt.value, nil).public_send(polarity, *arguments, &)
      rescue RSpec::Expectations::ExpectationNotMetError => e
        raise e.exception("(waited #{Raider::Describe.seconds(waited)}s) #{e.message}")
      end
    end
  end
end
