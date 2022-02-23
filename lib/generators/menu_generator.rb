require 'highline'

module RubyRaider
  class MenuGenerator
    def self.generate_choice_menu
      cli = HighLine.new
      cli.choose do |menu|
        menu.prompt = 'Please select your automation framework'
        menu.choice(:Selenium) { @automation = 'selenium', choose_test_framework }
        menu.choice(:Watir) { @automation = 'watir', choose_test_framework }
        menu.choice(:Appium) { @automation = 'appium', choose_test_framework }
        menu.choice(:Quit, 'Exit program.') { exit }
      end
    end

    def choose_test_framework
      system('clear') || system('cls')
      sleep 0.3
      cli = HighLine.new
      cli.choose do |menu|
        menu.prompt = 'Please select your test framework'
        menu.choice(:Rspec) { @test = 'rspec', 'You choose this' }
        menu.choice(:Cucumber) { @test = 'cucumber', 'You choose this' }
        menu.choice(:Quit, 'Exit program.') { exit }
      end
    end
  end
end
