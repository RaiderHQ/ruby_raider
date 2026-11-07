# frozen_string_literal: true

require 'selenium-webdriver'

module Raider
  # Decides whether strictness and actionability apply: on for Selenium drivers
  # and Appium webviews, off on an Appium NATIVE_APP context.
  module Context
    NATIVE = 'NATIVE_APP'

    class << self
      def web?(bridge)
        return true unless contextual?(bridge)

        bridge.current_context != NATIVE
      end

      def web_for?(search_context)
        bridge = search_context.instance_variable_get(:@bridge)
        bridge.nil? || web?(bridge)
      end

      private

      # Appium bridges answer current_context; an event-firing wrapper delegates it.
      def contextual?(bridge)
        bridge.respond_to?(:current_context)
      end
    end
  end
end
