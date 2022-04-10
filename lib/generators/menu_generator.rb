require 'highline'
require_relative '../generators/projects/cucumber_project_generator'
require_relative '../generators/projects/rspec_project_generator'

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
          menu.choice('Rspec') { framework = 'rspec'; set_framework(automation, framework, project_name) }
          menu.choice('Cucumber') do
            if %w[selenium watir].include? automation
              framework = 'cucumber'
              set_framework(automation, framework, project_name)
            else
              pp 'We will support iOS with cucumber on the next release'
              exit
            end
          end
          menu.choice('Quit') { exit }
        end
        @cli.say("You have chosen to use #{framework} with #{automation}")
      end

      def set_framework(automation, framework, project_name)
        if framework == 'rspec'
          RspecProjectGenerator.generate_rspec_project(automation, project_name)
        else
          CucumberProjectGenerator.generate_cucumber_project(automation, project_name)
        end
      end

      def choose_mobile_platform
        @cli.choose do |menu|
          menu.prompt = 'Please select your mobile platform'
          menu.choice('iOS') { 'appium_ios' }
          menu.choice('Android') { pp 'Android appium is coming soon. Thank you for the interest'; exit }
          menu.choice('Cross Platform') { pp 'Cross platform appium is coming soon. Thank you for the interest'; exit }
          menu.choice('Quit') { exit }
        end
      end
    end
  end
end
