# frozen_string_literal: true

require 'tty-prompt'
require_relative '../generators/invoke_generators'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
module RubyRaider
  class MenuGenerator
    attr_reader :prompt, :name

    include InvokeGenerators

    def initialize(project_name)
      @prompt = TTY::Prompt.new
      @name = project_name
    end

    def generate_choice_menu
      prompt.select('Please select your automation framework') do |menu|
        select_automation_framework(menu)
      end
    end

    def choose_test_framework(automation)
      return choose_mobile_platform if automation == 'appium'

      select_test_framework(automation)
    end

    def set_up_framework(options)
      structure = {
        automation: options[:automation],
        framework: options[:framework],
        name: @name
      }
      generate_framework(structure)
      system "cd #{name} && gem install bundler && bundle install"
    end

    def choose_mobile_platform
      prompt.select('Please select your mobile platform') do |menu|
        menu.choice :iOS, -> { choose_test_framework 'ios' }
        menu.choice :Android, -> { choose_test_framework 'android' }
        menu.choice :Cross_Platform, -> { choose_test_framework 'cross_platform' }
        menu.choice :Quit, -> { exit }
      end
    end

    private

    def select_test_framework(automation)
      prompt.select('Please select your test framework') do |menu|
        menu.choice :Cucumber, -> { create_framework('Cucumber', automation) }
        menu.choice :Rspec, -> { create_framework('Rspec', automation) }
        menu.choice :Quit, -> { exit }
      end
    end

    FrameworkOptions = Struct.new(:automation, :framework)

    def create_framework_options(params)
      FrameworkOptions.new(params[:automation], params[:framework])
    end

    def create_framework(framework, automation_type)
      options = create_framework_options(automation: automation_type,
                                         framework: framework.downcase)

      # Print the chosen options
      puts 'Chosen Options:'
      puts "  Automation Type: #{options[:automation]}"
      puts "  Framework: #{options[:framework]}"

      set_up_framework(options)
      prompt.say("You have chosen to use #{framework} with #{automation_type}")
    end

    def yes_no_menu_choices
      {
        Yes: -> { true },
        No: -> { false },
        Quit: -> { exit }
      }
    end

    def select_automation_framework(menu)
      menu.choice :Selenium, -> { choose_test_framework('selenium') }
      menu.choice :Appium, -> { choose_test_framework('appium') }
      menu.choice :Watir, -> { choose_test_framework('watir') }
      menu.choice :Applitools, -> { choose_test_framework('applitools') }
      menu.choice :Axe, -> { choose_test_framework('axe') }
      menu.choice :Quit, -> { exit }
    end
  end
end