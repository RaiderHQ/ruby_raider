# frozen_string_literal: true

require 'selenium-webdriver'

module Raider
  module Spec
    # A stand-in for Selenium's remote bridge: converts locators the way a real
    # bridge does, records what reaches the wire and answers from a script.
    class FakeBridge
      attr_reader :calls, :script_results

      def initialize
        @locator_converter = Selenium::WebDriver::Remote::Bridge.locator_converter
        @calls = []
        @queue = []
        @script_results = []
      end

      def enqueue(ids)
        @queue << ids
      end

      def find_element_by(how, what, ref = [])
        how, what = @locator_converter.convert(how, what)
        calls << [:find_element_by, how, what, ref]
        ids = @queue.shift || []
        raise Selenium::WebDriver::Error::NoSuchElementError, 'no such element' if ids.empty?

        wrap(ids.first)
      end

      def find_elements_by(how, what, ref = [])
        how, what = @locator_converter.convert(how, what)
        calls << [:find_elements_by, how, what, ref]
        (@queue.shift || []).map { |id| wrap(id) }
      end

      def execute_script(_script, *_args)
        script_results.shift
      end

      def element_class
        Selenium::WebDriver::Element
      end

      private

      def wrap(id)
        Selenium::WebDriver::Element.new(self, id)
      end
    end

    # An initialized real bridge of klass, built without a network call: the
    # initializer signature differs across selenium versions.
    def self.real_bridge(klass)
      keywords = Selenium::WebDriver::Remote::Bridge.instance_method(:initialize).parameters.map(&:last)
      args = { http_client: Selenium::WebDriver::Remote::Http::Default.new }
      args[:url] = 'http://127.0.0.1:4444/' if keywords.include?(:url)
      klass.allocate.tap { |bridge| bridge.send(:initialize, **args) }
    end

    def self.driver(bridge)
      Selenium::WebDriver::Driver.allocate.tap { |driver| driver.instance_variable_set(:@bridge, bridge) }
    end
  end
end
