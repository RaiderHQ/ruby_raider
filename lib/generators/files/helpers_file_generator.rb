require_relative 'file_generator'

module RubyRaider
  class HelpersFileGenerator < FileGenerator
    def self.generate_helper_files(name, automation)
      generate_file('raider.rb', "#{name}/helpers", generate_raider_helper((automation)))
      generate_file('allure_helper.rb', "#{name}/helpers", generate_allure_helper)
      generate_file('browser_helper.rb', "#{name}/helpers", generate_browser_helper)
      generate_file('pom_helper.rb', "#{name}/helpers", generate_pom_helper)
      generate_file('spec_helper.rb', "#{name}/helpers", generate_spec_helper)
      if automation == 'watir'
        generate_file('watir_helper.rb', "#{name}/helpers", generate_watir_helper)
      else
        generate_file('selenium_helper.rb', "#{name}/helpers", generate_selenium_helper)
      end
    end

    def self.generate_raider_helper(automation)
      spec = ERB.new <<~EOF
        module Raider
          require_relative 'spec_helper'
          require_relative '#{automation}_helper'
          require_relative 'pom_helper'
          require_relative 'browser_helper'
          require_relative 'allure_helper'
        end
      EOF
      spec.result(binding)
    end

    def self.generate_allure_helper
      spec = ERB.new <<~EOF
        require 'allure-ruby-commons'
        require 'allure-rspec'

        module Raider
          module AllureHelper
            class << self

              def configure
                AllureRspec.configure do |config|
                  config.results_directory = 'allure-results'
                  config.clean_results_directory = true
                end
              end

              def add_screenshot(name)
                Allure.add_attachment(
                  name: name,
                  source: File.open("allure-results/screenshots/#{name}.png"),
                  type: Allure::ContentType::PNG,
                  test_case: true
                )
              end

              def formatter
                AllureRspecFormatter
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

    def self.generate_spec_helper
      spec = ERB.new <<~EOF
        require 'active_support/all'
        require 'rspec'
        require_relative 'allure_helper'
        require_relative 'browser_helper'

        module Raider
          module SpecHelper

            AllureHelper.configure

            RSpec.configure do |config|
              config.formatter = AllureHelper.formatter
              config.before(:each) do
                BrowserHelper.new_browser
              end

              config.after(:each) do
                browser = BrowserHelper.browser
                example_name = self.class.descendant_filtered_examples.first.description
                status = self.class.descendant_filtered_examples.first.execution_result.status
                browser.save_screenshot("allure-results/screenshots/#\{example_name}.png") if status == :failed
                AllureHelper.add_screenshot example_name if status == :failed
                browser.quit
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

        module ExampleDsl
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
  end
end