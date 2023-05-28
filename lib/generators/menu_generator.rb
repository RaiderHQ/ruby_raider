# frozen_string_literal: true

require 'tty-prompt'
require_relative '../generators/invoke_generators'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
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
    prompt.select('Do you want to add visual automation with applitools?', visual_automation_menu_choices)
  end

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'

    select_test_framework(automation)
  end

  def set_up_framework(options)
    structure = {
      automation: options[:automation],
      framework: options[:framework],
      name: @name,
      visual: options[:visual_automation],
      examples: options[:with_examples]
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
      menu.choice :Cucumber, -> { select_example_files('Cucumber', automation) }
      menu.choice :Rspec, -> { select_example_files('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_example_files(framework, automation)
    prompt.select('Would you like to create example files?') do |menu|
      menu.choice :Yes, -> { framework_with_examples(framework, automation) }
      menu.choice :No, -> { framework_without_examples(framework, automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  FrameworkOptions = Struct.new(:automation, :framework, :visual_automation, :with_examples)

  def create_framework_options(params)
    FrameworkOptions.new(params[:automation], params[:framework], params[:visual_automation], params[:with_examples])
  end

  def framework_with_examples(framework, automation_type)
    visual_automation = choose_visual_automation if %w[selenium].include?(automation_type)
    options = create_framework_options(automation: automation_type, framework: framework.downcase, visual_automation: visual_automation, with_examples: true)
    set_up_framework(options)
    prompt.say("You have chosen to use #{framework} with #{automation_type}")
  end

  def framework_without_examples(framework, automation_type)
    visual_automation = choose_visual_automation if %w[selenium].include?(automation_type)
    options = create_framework_options(automation: automation_type, framework: framework.downcase, visual_automation: visual_automation, with_examples: false)
    set_up_framework(options)
    prompt.say("You have chosen to use #{framework} with #{automation_type}")
  end

  def visual_automation_menu_choices
    {
      Yes: -> { true },
      No: -> { false },
      Quit: -> { exit }
    }
  end
end
