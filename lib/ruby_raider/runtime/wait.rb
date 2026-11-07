# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'
require_relative 'errors'

module Raider
  # The runtime wait loop. Nested waits share one deadline through DEADLINE_KEY
  # (the same key the generated wait helper uses).
  module Wait
    DEADLINE_KEY = :raider_wait_deadline
    IMMEDIATE_KEY = :raider_wait_immediate

    class << self
      def deadline
        Thread.current[DEADLINE_KEY]
      end

      # Runs the block with finds making one attempt each (the caller does the waiting).
      def immediately
        previous = Thread.current[IMMEDIATE_KEY]
        Thread.current[IMMEDIATE_KEY] = true
        yield
      ensure
        Thread.current[IMMEDIATE_KEY] = previous
      end

      def immediate?
        Thread.current[IMMEDIATE_KEY] == true
      end

      # Polls until the block returns a truthy value. The block may
      # `throw :not_ready, reason` to say why it is not ready yet.
      def until(timeout: nil, interval: 0.1)
        limit, = limits(timeout)
        within(limit) do
          reason = nil
          loop do
            result = nil
            thrown = catch(:not_ready) do
              result = yield
              nil
            end
            return result if result

            reason = thrown || reason
            raise TimeoutError, reason || 'condition not met' if now >= limit

            pause(limit, interval)
          end
        end
      end

      # Retries the block on expectation and lookup failures until the deadline,
      # then re-raises the last error with the time waited prefixed.
      def eventually(timeout: nil)
        limit, waited = limits(timeout)
        within(limit) do
          loop do
            return yield
          rescue *retried_errors => e
            raise e.exception("(still failing after #{Describe.seconds(waited)}s)\n#{e.message}") if now >= limit

            pause(limit, 0.1)
          end
        end
      end

      private

      def retried_errors
        errors = [Selenium::WebDriver::Error::NoSuchElementError,
                  Selenium::WebDriver::Error::StaleElementReferenceError,
                  AmbiguousMatch, NotActionable, TimeoutError]
        errors.unshift(RSpec::Expectations::ExpectationNotMetError) if defined?(RSpec::Expectations)
        errors
      end

      # Inside an enclosing deadline, a call without timeout waits for what is left;
      # one with timeout waits that long, never past the enclosing deadline.
      def limits(timeout)
        started = now
        enclosing = deadline
        own = started + (timeout || Raider.timeout) if timeout || !enclosing
        limit = [own, enclosing].compact.min
        [limit, limit - started]
      end

      def within(limit)
        enclosing = deadline
        Thread.current[DEADLINE_KEY] = limit
        yield
      ensure
        Thread.current[DEADLINE_KEY] = enclosing
      end

      def pause(limit, interval)
        sleep([[interval, limit - now].min, 0].max)
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end

  def self.eventually(timeout: nil, &)
    Wait.eventually(timeout: timeout, &)
  end
end
