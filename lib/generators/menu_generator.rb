require 'highline'
require_relative '../generators/projects/rspec_project_generator'

module RubyRaider
  class MenuGenerator
    def self.generate_choice_menu(project_name)
      cli = HighLine.new
      cli.choose do |menu|
        menu.prompt = 'Please select your automation framework'
        menu.choice(:Selenium) { 'We are still working on supporting this' }
        menu.choice(:Watir) {choose_test_framework('watir', project_name) }
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
        menu.choice(:Rspec) { framework = 'Rspec'; set_rspec_framework(automation, project_name)}
        menu.choice(:Cucumber) { framework = 'cucumber'; 'We are still working on supporting this' }
        menu.choice(:Quit, 'Exit program.') { exit }
      end
      cli.say("You have chosen to use #{framework} with #{automation}")
    end

    def self.set_rspec_framework(automation, project_name)
      RspecProjectGenerator.generate_rspec_project(project_name, automation: automation)
      ProjectGenerator.install_gems(project_name)
    end
  end
end
