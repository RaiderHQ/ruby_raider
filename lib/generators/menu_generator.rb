require 'highline'
require_relative '../generators/projects/cucumber_project_generator'
require_relative '../generators/projects/rspec_project_generator'

module RubyRaider
  class MenuGenerator
    def self.generate_choice_menu(project_name)
      cli = HighLine.new
      cli.choose do |menu|
        menu.prompt = 'Please select your automation framework'
        menu.choice(:Selenium) { choose_test_framework('selenium', project_name) }
        menu.choice(:Watir) { choose_test_framework('watir', project_name) }
        menu.choice(:Quit, 'Exit program.') { exit }
      end
    end

    def self.choose_test_framework(automation, project_name)
      system('clear') || system('cls')
      sleep 0.3
      cli = HighLine.new
      framework = ''
      cli.choose do |menu|
        menu.prompt = 'Please select your test framework'
        menu.choice(:Rspec) do
          framework = 'rspec'
          set_framework(automation, framework, project_name)
        end
        menu.choice(:Cucumber) do
          framework = 'cucumber'
          set_framework(automation, framework, project_name)
        end
        menu.choice(:Quit, 'Exit program.') { exit }
      end
      cli.say("You have chosen to use #{framework} with #{automation}")
    end

    def self.set_framework(automation, framework, project_name)
      if framework == 'rspec'
        RspecProjectGenerator.generate_rspec_project(project_name, automation: automation)
      else
        CucumberProjectGenerator.generate_cucumber_project(project_name, automation: automation)
      end
    end
  end
end
