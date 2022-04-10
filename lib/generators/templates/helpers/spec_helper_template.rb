require_relative '../template'

class SpecHelperTemplate < Template
  def require_driver
    "require_relative '#{@automation == 'watir' ? 'browser_helper' : 'driver_helper'}'"
  end

  def select_helper
    @automation == 'watir' ? 'BrowserHelper.new_browser' : 'DriverHelper.new_driver'
  end

  def before_configuration
    driver_setup = if %w[selenium watir].include?(@automation)
                     select_helper
                   else
                     <<-EOF.chomp
#{select_helper}
         DriverHelper.driver.start_driver
                     EOF
                   end

    <<-EOF.chomp

      config.before(:each) do
        #{driver_setup}
      end
    EOF
  end

  def quit_driver
    case @automation
    when 'selenium'
      'DriverHelper.driver.quit'
    when 'watir'
      'BrowserHelper.browser.quit'
    else
      'DriverHelper.driver.quit_driver'
    end
  end

  def save_screenshot
    driver = @automation == 'watir' ? 'browser' : 'driver'
    "#{driver}.save_screenshot(\"allure-results/screenshots/\#{example_name}.png\") if status == :failed"
  end

  def body
    <<~EOF
      require 'active_support/all'
      require 'rspec'
      require_relative 'allure_helper'
      #{require_driver}

      module Raider
        module SpecHelper

          AllureHelper.configure

          RSpec.configure do |config|
            config.formatter = AllureHelper.formatter
            #{before_configuration}

            config.after(:each) do
              example_name = self.class.descendant_filtered_examples.first.description
              status = self.class.descendant_filtered_examples.first.execution_result.status
              #{save_screenshot}
              AllureHelper.add_screenshot example_name if status == :failed
              #{quit_driver}
            end
          end
        end
      end
    EOF
  end
end
