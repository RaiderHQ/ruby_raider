# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'errors'
require_relative 'locator_converter'

module Raider
  FINDERS = {
    label: 'raider label',
    placeholder: 'raider placeholder',
    alt: 'raider alt',
    title: 'raider title',
    text: 'raider text',
    test_id: 'raider test id',
    role: 'raider role'
  }.freeze

  # Registers the Raider locator keys and converter on Selenium and Appium.
  module Finders
    BRIDGE = 'Selenium::WebDriver::Remote::Bridge'
    SEARCH_CONTEXT = 'Selenium::WebDriver::SearchContext'

    module_function

    def register
      context = Selenium::WebDriver::SearchContext
      context.extra_finders = (context.extra_finders || {}).merge(FINDERS)
    end

    # Covers a late `require 'appium_lib'`, which overwrites the finder table
    # and assigns its own bridge converter. Bridges created before the wrap keep
    # the converter they copied; require the runtime before creating a driver.
    def ensure_registered
      register unless Selenium::WebDriver::SearchContext.finders.key?(:label)
      install_converter(Appium::Core::Base::Bridge) if defined?(Appium::Core::Base::Bridge)
    end

    def install_converter(bridge_class)
      return if bridge_class.locator_converter.is_a?(LocatorConverter)

      bridge_class.locator_converter = LocatorConverter.new(bridge_class.locator_converter)
    end

    def install
      register
      install_converter(Selenium::WebDriver::Remote::Bridge)
      install_converter(Appium::Core::Base::Bridge) if defined?(Appium::Core::Base::Bridge)
    end

    def check_api
      bridge = Selenium::WebDriver::Remote::Bridge
      context = Selenium::WebDriver::SearchContext
      raise Error, "#{BRIDGE} must respond to locator_converter=" unless bridge.respond_to?(:locator_converter=)
      raise Error, "#{SEARCH_CONTEXT} must respond to extra_finders=" unless context.respond_to?(:extra_finders=)
    end

    def guard
      return unless ObjectSpace.each_object(Selenium::WebDriver::Remote::Bridge).any?

      raise Error, "require 'ruby_raider/runtime' before creating the driver"
    end
  end
end
