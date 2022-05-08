# frozen_string_literal: true

require 'highline'
require_relative 'automation_generator'
require_relative 'common_generator'
require_relative 'cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec_generator'

module RubyRaider
  class MenuGenerator
    class << self
      def generate_choice_menu(project_name)
        @cli = HighLine.new
        @cli.choose do |menu|
          menu.prompt = 'Please select your automation framework'
          menu.choice('Selenium') { choose_test_framework('selenium', project_name) }
          menu.choice('Watir') { choose_test_framework('watir', project_name) }
          menu.choice('Appium') { choose_test_framework('appium', project_name) }
          menu.choice('Quit') { exit }
        end
      end

      def choose_test_framework(automation, project_name)
        system('clear') || system('cls')
        sleep 0.3
        automation = automation == 'appium' ? choose_mobile_platform : automation
        framework = ''
        @cli.choose do |menu|
          menu.prompt = 'Please select your test framework'
          menu.choice('Rspec') do
            framework = 'rspec'
            set_framework(automation, framework, project_name)
          end
          menu.choice('Cucumber') do
            framework = 'cucumber'
            set_framework(automation, framework, project_name)
          end
          menu.choice('Quit') { exit }
        end
        @cli.say("You have chosen to use #{framework} with #{automation}")
      end

      def set_framework(automation, framework, project_name)
        if framework == 'rspec'
          RspecGenerator.new([automation, framework, project_name]).invoke_all
        else
          CucumberGenerator.new([automation, framework, project_name]).invoke_all
        end
        AutomationGenerator.new([automation, framework, project_name]).invoke_all
        CommonGenerator.new([automation, framework, project_name]).invoke_all
        HelpersGenerator.new([automation, framework, project_name]).invoke_all
        system "cd #{project_name} && gem install bundler && bundle install"
      end

      def choose_mobile_platform
        @cli.choose do |menu|
          menu.prompt = 'Please select your mobile platform'
          menu.choice('iOS') { 'appium_ios' }
          menu.choice('Android') do
            pp 'Android appium is coming soon. Thank you for the interest'
            exit
          end
          menu.choice('Cross Platform') do
            pp 'Cross platform appium is coming soon. Thank you for the interest'
            exit
          end
          menu.choice('Quit') { exit }
        end
      end
    end
  end
end
