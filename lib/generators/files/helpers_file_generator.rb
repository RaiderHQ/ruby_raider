require_relative 'file_generator'

module RubyRaider
  class HelpersFileGenerator < FileGenerator
    def self.generate_helper_files(name, automation, framework)
      path = framework == 'rspec' ? "#{name}/helpers" : "#{name}/features/support/helpers"
      generate_file('raider.rb', path, generate_raider_helper(automation, framework))
      generate_file('allure_helper.rb', path, generate_allure_helper(framework))
      generate_file('pom_helper.rb', path, generate_pom_helper)
      generate_file('spec_helper.rb', path, generate_spec_helper((automation))) if framework == 'rspec'
      if automation == 'watir'
        generate_file('watir_helper.rb', path, generate_watir_helper)
        generate_file('browser_helper.rb', path, generate_browser_helper)
      else
        generate_file('selenium_helper.rb', path, generate_selenium_helper)
        generate_file('driver_helper.rb', path, generate_driver_helper)
      end
    end

    def self.generate_raider_helper(automation, framework)
      spec = ERB.new <<~EOF
        module Raider
          #{"require_relative 'spec_helper'" if framework == 'rspec'}
          require_relative '#{automation}_helper'
          require_relative 'pom_helper'
          require_relative '#{automation == 'watir' ? 'browser_helper' : 'driver_helper'}'
          require_relative 'allure_helper'
        end
      EOF

      spec.result(binding)
    end

    def self.generate_allure_helper(framework)
      if framework == 'cucumber'
        gems = "require 'allure-cucumber'"
        allure = 'AllureCucumber'
      else
        gems = "require 'allure-ruby-commons'
                require 'allure-rspec'"
        allure = 'AllureRspec'
      end
      spec = ERB.new <<~EOF
        #{gems}

        module Raider
          module AllureHelper
            class << self

              def configure
                #{allure}.configure do |config|
                  config.results_directory = 'allure-results'
                  config.clean_results_directory = true
                end
              end

              def add_screenshot(screenshot_name)
                Allure.add_attachment(
                  name: name,
                  source: "File.open(allure-results/screenshots/\#{screenshot_name}.png)",
                  type: Allure::ContentType::PNG,
                  test_case: true
                )
              end
            end
          end
        end
      EOF
      spec.result(binding)
    end

    def self.generate_browser_helper
      spec = ERB.new <<~EOF
        require 'yaml'
        require 'selenium-webdriver'
        require 'watir'
        require 'webdrivers'

        module Raider
          module BrowserHelper
            class << self
              attr_reader :browser

              def new_browser
                config = YAML.load_file('config/config.yml')
                @browser = Watir::Browser.new config['browser']
              end
            end
          end
        end

      EOF
      spec.result(binding)
    end

    def self.generate_pom_helper
      spec = ERB.new <<~EOF
        module Raider
          module PomHelper
            def instance
              @instance ||= new
            end

            def method_missing(message, *args, &block)
              return super unless instance.respond_to?(message)

              instance.public_send(message, *args, &block)
            end

            def respond_to_missing?(method, *_args, &block)
              instance.respond_to?(method) || super
            end
          end
        end
      EOF
      spec.result(binding)
    end

    def self.generate_spec_helper(automation)
      spec = ERB.new <<~EOF
        require 'active_support/all'
        require 'rspec'
        require_relative 'allure_helper'
        require_relative '#{automation == 'watir' ? 'browser_helper' : 'driver_helper'}'

        module Raider
          module SpecHelper

            AllureHelper.configure

            RSpec.configure do |config|
              config.formatter = AllureHelper.formatter
              config.before(:each) do
                #{automation == 'watir' ? 'BrowserHelper.new_browser' : 'DriverHelper.new_driver'}
              end

              config.after(:each) do
                #{automation == 'watir' ? 'browser = BrowserHelper.browser' : 'driver = DriverHelper.driver'}
                example_name = self.class.descendant_filtered_examples.first.description
                status = self.class.descendant_filtered_examples.first.execution_result.status
                #{automation == 'watir' ? 'browser' : 'driver'}.save_screenshot("allure-results/screenshots/#\{example_name}.png") if status == :failed
                AllureHelper.add_screenshot example_name if status == :failed
                #{automation == 'watir' ? 'browser.quit' : 'driver.quit'}
              end
            end
          end
        end
      EOF
      spec.result(binding)
    end

    def self.generate_watir_helper
      spec = ERB.new <<~EOF
        require 'watir'

        module Raider
          module WatirHelper
            refine Watir::Element do
              def click_when_present
                wait_until_present
                self.click
              end

              def wait_until_present
                self.wait_until(&:present?)
              end
            end
          end
        end
      EOF
      spec.result(binding)
    end

    def self.generate_selenium_helper
      spec = ERB.new <<~EOF
        require 'selenium-webdriver'
        require_relative 'driver_helper'

        module Raider
          module SeleniumHelper
            def click_when_present
              # This is an example of an implicit wait in selenium
              wait = Selenium::WebDriver::Wait.new(timeout: 15)
              wait.until { present? }
              click
            end

            def select_by(key, value)
              # Creates new Select object to use the select by method
              dropdown = Selenium::WebDriver::Support::Select.new self
              dropdown.select_by(key, value)
            end

            def hover
              # Using actions to move the mouse over an element
              DriverHelper.driver.action.move_to(self).perform
            end

            # How to perform right click through the context click method
            def right_click
              DriverHelper.driver.action.context_click(self).perform
            end
          end

          # Here we are opening the selenium class and adding our custom method
          class Selenium::WebDriver::Element
            include SeleniumHelper
          end
        end

      EOF
      spec.result(binding)
    end

    def self.generate_driver_helper
      spec = ERB.new <<~EOF
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
      spec.result(binding)
    end
  end
end