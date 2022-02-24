require 'highline'
require_relative '../generators/projects/project_generator'

module RubyRaider
  class MenuGenerator
    def self.generate_choice_menu
      cli = HighLine.new
      cli.choose do |menu|
        menu.prompt = 'Please select your automation framework'
        menu.choice(:Selenium) { choose_test_framework('selenium') }
        menu.choice(:Watir) {choose_test_framework('watir') }
        menu.choice(:Quit, 'Exit program.') { exit }
      end
    end

    def self.choose_test_framework(automation)
      system('clear') || system('cls')
      sleep 0.3
      cli = HighLine.new
      framework = ''
      cli.choose do |menu|
        menu.prompt = 'Please select your test framework'
        menu.choice(:Rspec) { framework = 'Rspec', ProjectGenerator.generate_rspec_project(automation) }
        menu.choice(:Cucumber) { framework = 'cucumber', 'You choose this' }
        menu.choice(:Quit, 'Exit program.') { exit }
      end
      cli.say("You have chosen to use #{framework} with #{automation}")
    end
  end
end
