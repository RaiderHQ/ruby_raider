require_relative '../template'

class DriverHelperTemplate < Template
  def new_driver
    if @automation == 'selenium'
      <<-EOF.chomp
def new_driver
        @driver = Selenium::WebDriver.for :chrome
      end
      EOF
    else
      <<-EOF.chomp
def new_driver
        appium_file = File.join(Dir.pwd, 'appium.txt')
        caps = Appium.load_appium_txt(file: appium_file)
        @driver = Appium::Driver.new(caps)
      end
      EOF
    end
  end

  def requirements
    case @automation
    when 'selenium'
      <<~EOF
        require 'selenium-webdriver'
        require 'webdrivers'
      EOF
    when 'watir'
      <<~EOF
        require 'watir'
        require 'webdrivers'
      EOF
    else
      "require 'appium_lib'"
    end
  end

  def body
    <<~EOF
      #{requirements}

      module Raider
        module DriverHelper
          class << self
            attr_reader :driver

            #{new_driver}
          end
        end
      end
    EOF
  end
end
