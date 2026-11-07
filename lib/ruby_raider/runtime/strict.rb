# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'
require_relative 'errors'
require_relative 'context'
require_relative 'finders'

module Raider
  # Renders a find_element argument list for error messages.
  module Locator
    module_function

    def describe(args)
      how, what = args
      args.size == 1 && how.is_a?(Hash) ? from_hash(how) : "{ #{how.to_s.inspect}: #{what.inspect} }"
    rescue StandardError
      args.inspect
    end

    def from_hash(hash)
      key, value = hash.first
      return "by_role(#{role_arguments(value)})" if key == :role && value.is_a?(Array)

      "{ #{key}: #{plain_arguments(value)} }"
    end

    def role_arguments(value)
      name, options = value
      ["'#{name}'", *render_options(options)].join(', ')
    end

    def plain_arguments(value)
      return value.inspect unless value.is_a?(Array)

      text, options = value
      [text.inspect, *render_options(options)].join(', ')
    end

    def render_options(options)
      return [] unless options.is_a?(Hash)

      options.map { |key, option| "#{key}: #{option.inspect}" }
    end
  end

  # Prepended to SearchContext: find_element must match exactly one element, and
  # both finds wait for a match.
  module StrictFinder
    def find_element(*args)
      Finders.ensure_registered
      attempt = element_attempt(args) { super(*args) }
      return attempt.call || raise(Selenium::WebDriver::Error::NoSuchElementError, not_found(args)) if Wait.immediate?

      started = clock
      begin
        Wait.until(timeout: Raider.timeout) { attempt.call }
      rescue TimeoutError
        raise Selenium::WebDriver::Error::NoSuchElementError,
              "#{not_found(args)} (waited #{Describe.seconds(clock - started)}s)"
      end
    end

    def find_elements(*args)
      return super if Wait.immediate?

      attempt = elements_attempt(args) { super(*args) }
      found = []
      begin
        Wait.until(timeout: Raider.timeout) { (found = attempt.call).any? }
      rescue TimeoutError
        nil
      end
      found
    end

    private

    # A callable making one attempt at the element: the element, or nil when nothing
    # matched yet. The context is decided here, once per find, not per attempt.
    def element_attempt(args, &raw)
      if RoleFinder.role_args?(args)
        queried = role_attempt(args)
        strict = Raider.strict
        return -> { sole(args, queried.call, strict) }
      end
      return -> { native_or_nil(&raw) } unless Raider.strict && Context.web?(bridge)

      -> { sole(args, Wait.immediately { find_elements(*args) }, true) }
    end

    def elements_attempt(args, &raw)
      RoleFinder.role_args?(args) ? role_attempt(args) : raw
    end

    # Validates the role locator and checks the context once, then queries the engine directly.
    def role_attempt(args)
      role, options = RoleFinder.parse(args)
      raise NotSupported, RoleFinder::NATIVE_MESSAGE unless Context.web?(bridge)

      scope = is_a?(Selenium::WebDriver::Driver) ? nil : self
      -> { RoleQuery.run(bridge, scope, role, options) }
    end

    def sole(args, found, strict)
      raise AmbiguousMatch.new(Locator.describe(args), found) if strict && found.size > 1

      found.first
    end

    def native_or_nil
      yield
    rescue Selenium::WebDriver::Error::NoSuchElementError
      nil
    end

    def not_found(args)
      "no such element: #{Locator.describe(args)}"
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

# Selenium aliases `first` to find_element on Driver and Element, which
# bypasses the prepend above; `find_elements(...).first` stays the non-strict escape.
module Raider
  # Routes Selenium's `first` alias through the strict find_element.
  module StrictFirst
    def first(*args) = find_element(*args)
  end
end

Selenium::WebDriver::SearchContext.prepend(Raider::StrictFinder)
[Selenium::WebDriver::Driver, Selenium::WebDriver::Element].each { |klass| klass.prepend(Raider::StrictFirst) }
