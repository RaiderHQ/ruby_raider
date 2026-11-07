# frozen_string_literal: true

require 'selenium-webdriver'

module Raider
  module Spec
    # A stand-in for Selenium's remote bridge: converts locators the way a real
    # bridge does, records what reaches the wire and answers from a script.
    # :reek:TooManyInstanceVariables -- one slot per scripted answer channel
    class FakeBridge
      attr_reader :calls, :script_results

      def initialize
        @locator_converter = Selenium::WebDriver::Remote::Bridge.locator_converter
        @calls = []
        @queue = []
        @script_results = []
        @answers = Hash.new { |hash, key| hash[key] = [] }
      end

      # Scripts per-poll answers for an element command; the last answer repeats.
      # An Exception class or instance is raised instead of returned.
      def answer(command, *values)
        @answers[command].concat(values)
        self
      end

      %i[element_text element_attribute element_displayed? element_enabled? element_selected?].each do |command|
        define_method(command) { |*_args| next_answer(command) }
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

      # Describe.element falls back to <element> when the tag cannot be read.
      def element_tag_name(_ref)
        raise Selenium::WebDriver::Error::WebDriverError, 'no tag'
      end

      def element_class
        Selenium::WebDriver::Element
      end

      private

      def next_answer(command)
        queue = @answers[command]
        value = queue.size > 1 ? queue.shift : queue.first
        raise value, 'scripted' if value.is_a?(Class) && value <= Exception

        value
      end

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
