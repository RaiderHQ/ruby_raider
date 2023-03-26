# frozen_string_literal: true

require 'tty-prompt'

class MenuGenerator
  attr_reader :prompt, :name

  include InvokeGenerators

  def initialize(project_name)
    @prompt = TTY::Prompt.new
    @name = project_name
  end

  def generate_choice_menu
    prompt.select('Please select your automation framework') do |menu|
      menu.choice :Appium, -> { choose_test_framework('appium') }
      menu.choice :Selenium, -> { choose_test_framework('selenium') }
      menu.choice :Watir, -> { choose_test_framework('watir') }
      menu.choice :Quit, -> { exit }
    end
  end

  def choose_visual_automation
    prompt.select('Do you want to add visual automation with applitools?') do |menu|
      menu.choice :Yes, -> { true }
      menu.choice :No, -> { false }
      menu.choice :Quit, -> { exit }
    end
  end

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'

    select_test_framework(automation)
  end

  def set_up_framework(automation, framework, visual_automation, with_examples)
    structure = {
      automation: automation,
      framework: framework,
      name: @name,
      visual: visual_automation,
      examples: with_examples
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

  def framework_choice(framework, automation_type, with_examples: true)
    visual_automation = choose_visual_automation if %w[selenium watir].include?(automation_type) && framework == 'Rspec'

    set_up_framework(automation_type, framework.downcase, visual_automation, with_examples)
    prompt.say("You have chosen to use #{framework} with #{automation_type}")
  end

  def select_test_framework(automation)
    prompt.select('Please select your test framework') do |menu|
      menu.choice :Cucumber, -> { select_example_files('Cucumber', automation) }
      menu.choice :Rspec, -> { select_example_files('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_example_files(framework, automation)
    prompt.select('Would you like to create example files?') do |menu|
      menu.choice :Yes, -> { framework_choice(framework, automation) }
      menu.choice :No, -> { framework_choice(framework, automation, with_examples: false) }
      menu.choice :Quit, -> { exit }
    end
  end
end
