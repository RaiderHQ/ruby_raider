# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'eyes_selenium'
require_relative 'allure_helper'
require_relative 'driver_helper'
require_relative 'visual_helper'

module SpecHelper
    RSpec.configure do |config|
      config.include(DriverHelper)
      config.include(VisualHelper)
      config.before(:each) do
        OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
        @grid_runner = create_grid_runner
        @eyes = create_eyes(@grid_runner)
        configure_eyes @eyes
        @driver = @eyes.open(driver: driver)
      end

      config.after(:each) do |example|
        example_name = example.description
        Dir.mktmpdir do |temp_folder|
          screenshot = driver.save_screenshot("#{temp_folder}/#{example_name}.png")
          AllureHelper.add_screenshot(example_name, screenshot)
        end
        @eyes.close
        @driver.quit
        @eyes.abort_async
        results = @grid_runner.get_all_test_results
        puts results
      end
  end
end
