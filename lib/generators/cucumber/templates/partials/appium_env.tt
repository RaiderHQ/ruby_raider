require 'tmpdir'
require_relative '../../helpers/allure_helper'
require_relative '../../helpers/driver_helper'

include DriverHelper

Before do
  AllureHelper.configure
  driver.start_driver
end

After do |scenario|
  Dir.mktmpdir do |temp_folder|
    screenshot = driver.screenshot("#{temp_folder}/#{scenario.name}.png")
    AllureHelper.add_screenshot(scenario.name, screenshot)
  end
  driver.quit_driver
end
