require_relative '../template'

class SeleniumHelperTemplate < Template
  def body
    <<~EOF
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
  end
end
