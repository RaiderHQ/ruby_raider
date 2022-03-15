require_relative 'file_generator'

module RubyRaider
  class CucumberFileGenerator < FileGenerator
    def self.generate_cucumber_files(name, automation)
      CommonFileGenerator.generate_common_files(name, 'cucumber')
      HelpersFileGenerator.generate_helper_files(name, automation, 'cucumber')
      generate_file('login.feature', "#{name}/features", example_feature)
      generate_file('login_steps.rb', "#{name}/features/step_definitions", example_steps)
      generate_file('env.rb', "#{name}/features/support", env(automation))
      AutomationFileGenerator.generate_automation_files(name, automation, 'framework')
    end

    def self.example_feature
      gemfile = ERB.new <<~EOF
        Feature: Login Page

        Scenario: A user can login
          Given I'm a registered user on the login page
          When I login with my credentials
          Then I can see the main page

      EOF
      gemfile.result(binding)
    end

    def self.example_steps
      gemfile = ERB.new <<~EOF
        require_relative '../../page_objects/pages/login_page'

        Given("I'm a registered user on the login page") do
          LoginPage.visit
        end

        When('I login with my credentials') do
          LoginPage.login('aguspe', '12341234')
        end

        When('I can see the main page') do
          expect(LoginPage.header.customer_name).to eq 'Welcome back Agustin'
        end
      EOF
      gemfile.result(binding)
    end

    def self.env(automation)
      if automation == 'watir'
        helper = 'helpers/browser_helper'
        browser = 'Raider::BrowserHelper.new_browser'
        get_browser = 'browser = Raider::BrowserHelper.new_browser'
        screenshot = 'browser.screenshot.save("allure-results/screenshots/#{scenario.name}.png")'
        quit = 'browser.quit'
      else
        helper = 'helpers/driver_helper'
        browser = 'Raider::DriverHelper.new_driver'
        get_browser = 'driver = Raider::DriverHelper.driver'
        screenshot = 'driver.save_screenshot("allure-results/screenshots/#{scenario.name}.png")'
        quit = 'driver.quit'
      end

      gemfile = ERB.new <<~EOF
        require 'active_support/all'
        require_relative 'helpers/allure_helper'
        require_relative '#{helper}'

        Before do
            Raider::AllureHelper.configure
            #{browser}
        end

        After do |scenario|
         #{get_browser}
          #{screenshot}
          Raider::AllureHelper.add_screenshot(scenario.name)
          #{quit}
        end
      EOF
      gemfile.result(binding)
    end
  end
end
