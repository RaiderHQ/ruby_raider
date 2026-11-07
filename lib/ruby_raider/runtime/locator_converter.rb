# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'errors'
require_relative 'selectors'

module Raider
  # Wraps a bridge's locator converter: translates the Raider wire names into
  # XPath or CSS through Raider::Selectors and hands every other locator,
  # Appium's included, to the converter it wraps untouched.
  class LocatorConverter
    XPATH = {
      'raider label' => :label,
      'raider text' => :text
    }.freeze
    ATTRIBUTES = {
      'raider placeholder' => 'placeholder',
      'raider alt' => 'alt',
      'raider title' => 'title'
    }.freeze
    TEST_ID = 'raider test id'
    ROLE = 'raider role'

    attr_reader :inner

    def initialize(inner)
      @inner = inner
    end

    def convert(how, what)
      key = how.to_s
      return inner.convert(how, what) unless owns?(key)
      raise NotSupported, 'internal error: the role finder did not intercept this role locator' if key == ROLE

      value, exact = split(key, what)
      raise ArgumentError, "#{label_for(key)}: needs a non-empty value" if value.to_s.strip.empty?

      translate(key, value, exact)
    end

    private

    def owns?(key)
      XPATH.key?(key) || ATTRIBUTES.key?(key) || [TEST_ID, ROLE].include?(key)
    end

    def translate(key, value, exact)
      return ['xpath', Selectors.public_send(XPATH.fetch(key), value, exact:)] if XPATH.key?(key)
      return ['css selector', Selectors.attribute_css(ATTRIBUTES.fetch(key), value, exact:)] if ATTRIBUTES.key?(key)

      ['css selector', Selectors.test_id(value)]
    end

    def split(key, what)
      return [what, false] unless what.is_a?(Array)

      value, options = what
      raise ArgumentError, "#{label_for(key)}: expected a value or [value, { exact: }]" unless valid_pair?(what)

      [value, options&.fetch(:exact, false) ? true : false]
    end

    def valid_pair?(pair)
      value, options = pair
      (value.is_a?(String) || value.is_a?(Symbol)) && (options.nil? || options.is_a?(Hash)) && pair.size <= 2
    end

    def label_for(key)
      key.delete_prefix('raider ').tr(' ', '_')
    end
  end
end
