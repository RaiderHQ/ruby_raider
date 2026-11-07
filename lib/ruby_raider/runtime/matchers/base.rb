# frozen_string_literal: true

require 'selenium-webdriver'
require_relative '../config'
require_relative '../errors'
require_relative '../wait'

module Raider
  module Matchers
    # Shared polling for the web-first matchers. Subclasses implement `read(subject)`,
    # `pass?(value)` and `verb`, and may override `absent_passes?`.
    class Base
      NOT_FOUND = Object.new.freeze

      # What the last poll saw, for the failure message.
      Poll = Struct.new(:actual, :subject, :value, :waited)

      attr_reader :expected

      def initialize(expected, wait: nil, **options)
        @expected = expected
        @wait = wait
        @options = options
        @poll = Poll.new(nil, nil, NOT_FOUND, nil)
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

      def poll(actual, negated:)
        @poll = Poll.new(actual, nil, NOT_FOUND, @wait || Raider.timeout)
        Raider::Wait.until(timeout: @poll.waited) { settled?(negated) }
        true
      rescue Raider::TimeoutError
        false
      end

      def settled?(negated)
        @poll.subject = resolve(@poll.actual)
        @poll.value = read(@poll.subject)
        pass?(@poll.value) != negated || throw(:not_ready)
      rescue *retried_errors
        @poll.value = NOT_FOUND
        absent_passes? && !negated || throw(:not_ready)
      end

      def retried_errors
        [Selenium::WebDriver::Error::NoSuchElementError,
         Selenium::WebDriver::Error::StaleElementReferenceError,
         Raider::AmbiguousMatch]
      end

      def accepts_timeout?(subject, method)
        subject.method(method).parameters.any? { |_kind, name| name == :timeout }
      end

      def message(polarity)
        "expected #{target} #{polarity} #{description}, #{last_seen} after #{Raider::Describe.seconds(@poll.waited)}s"
      end

      def target
        return 'the block' if @poll.actual.is_a?(Proc)

        Raider::Describe.element(@poll.subject || @poll.actual)
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
