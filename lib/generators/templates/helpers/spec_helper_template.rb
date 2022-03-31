require_relative '../template'

class SpecHelperTemplate < Template
  def body
    <<~EOF
      require 'active_support/all'
      require 'rspec'
      require_relative 'allure_helper'
      require_relative '#{@automation == 'watir' ? 'browser_helper' : 'driver_helper'}'

      module Raider
        module SpecHelper

          AllureHelper.configure

          RSpec.configure do |config|
            config.formatter = AllureHelper.formatter
            config.before(:each) do
              #{@automation == 'watir' ? 'BrowserHelper.new_browser' : 'DriverHelper.new_driver'}
            end

            config.after(:each) do
              #{@automation == 'watir' ? 'browser = BrowserHelper.browser' : 'driver = DriverHelper.driver'}
              example_name = self.class.descendant_filtered_examples.first.description
              status = self.class.descendant_filtered_examples.first.execution_result.status
              #{@automation == 'watir' ? 'browser' : 'driver'}.save_screenshot("allure-results/screenshots/#\{example_name}.png") if status == :failed
              AllureHelper.add_screenshot example_name if status == :failed
              #{@automation == 'watir' ? 'browser.quit' : 'driver.quit'}
            end
          end
        end
      end
    EOF
  end
end
