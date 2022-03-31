require_relative '../template'

class DriverHelperTemplate < Template
  def body
    <<~EOF
      require 'selenium-webdriver'
      require 'watir'
      require 'webdrivers'
      require 'yaml'

      module Raider
        module DriverHelper
          class << self
            attr_reader :driver

            def new_driver
              @driver = Selenium::WebDriver.for :chrome
            end
          end
        end
      end
    EOF
  end
end
