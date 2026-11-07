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

  # Prepended to SearchContext: find_element must match exactly one element.
  module StrictFinder
    def find_element(*args)
      Finders.ensure_registered
      return super unless Raider.strict && Context.web?(bridge)

      found = find_elements(*args)
      raise AmbiguousMatch.new(Locator.describe(args), found) if found.size > 1

      raise Selenium::WebDriver::Error::NoSuchElementError, "no such element: #{Locator.describe(args)}" if found.empty?

      found.first
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
