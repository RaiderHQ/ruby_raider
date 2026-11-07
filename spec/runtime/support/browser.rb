# frozen_string_literal: true

require 'selenium-webdriver'

module Raider
  module Spec
    # One headless Chrome per process, created after the runtime is required.
    module Browser
      FIXTURES_DIR = File.expand_path('../fixtures', __dir__)

      module_function

      def driver
        @driver ||= Selenium::WebDriver.for(:chrome, options: options)
      end

      def open(fixture)
        driver.navigate.to("file://#{File.expand_path(fixture, FIXTURES_DIR)}")
      end

      def quit
        @driver&.quit
        @driver = nil
      end

      def options
        Selenium::WebDriver::Chrome::Options.new.tap do |chrome|
          %w[--headless=new --no-sandbox --disable-dev-shm-usage --window-size=1280,900].each do |flag|
            chrome.add_argument(flag)
          end
        end
      end
    end
  end
end
