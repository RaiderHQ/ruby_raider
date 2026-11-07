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

      def fixture_url(fixture)
        "file://#{File.expand_path(fixture, FIXTURES_DIR)}"
      end

      def open(fixture)
        driver.navigate.to(fixture_url(fixture))
      end

      def bidi_driver
        @bidi_driver ||= Selenium::WebDriver.for(:chrome, options: options.tap { |chrome| chrome.web_socket_url = true })
      end

      def quit_bidi
        @bidi_driver&.quit
        @bidi_driver = nil
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
