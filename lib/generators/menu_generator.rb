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
      select_automation_framework(menu)
    end
  end

  def choose_visual_automation
    prompt.select('Do you want to add visual automation with Applitools?', yes_no_menu_choices)
  end

  def choose_axe_support
    prompt.select('Do you want to add Axe accessibility testing tool?', yes_no_menu_choices)
  end

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'
    return choose_sparkling_platform if automation == 'sparkling'

    select_test_framework(automation)
  end

  def set_up_framework(options)
    structure = {
      automation: options[:automation],
      framework: options[:framework],
      name: @name,
      visual: options[:visual_automation],
      axe_support: options[:axe_support]
    }
    generate_framework(structure)
    system "cd #{name} && gem install bundler && bundle install"
  end

  def choose_sparkling_platform
    prompt.select('Please select your mobile platform') do |menu|
      menu.choice :iOS, -> { choose_test_framework 'sparkling_ios' }
      menu.choice :Quit, -> { exit }
    end
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

  FrameworkOptions = Struct.new(:automation, :framework, :visual_automation, :axe_support)

  def create_framework_options(params)
    FrameworkOptions.new(params[:automation], params[:framework], params[:visual_automation], params[:axe_support])
  end

  def create_framework(framework, automation_type)
    visual_automation = choose_visual_automation if %w[selenium].include?(automation_type)
    axe = choose_axe_support if automation_type == 'selenium' && framework == 'Rspec' && visual_automation == false
    options = create_framework_options(automation: automation_type,
                                       framework: framework.downcase,
                                       visual_automation:,
                                       axe_support: axe)

    # Print the chosen options
    puts 'Chosen Options:'
    puts "  Automation Type: #{options[:automation]}"
    puts "  Framework: #{options[:framework]}"
    puts "  Visual Automation: #{options[:visual_automation]}"
    puts "  Axe Support: #{options[:axe_support]}"

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
    menu.choice :Appium, -> { choose_test_framework('appium') }
    menu.choice :Selenium, -> { choose_test_framework('selenium') }
    menu.choice 'Sparkling Watir', -> { choose_test_framework('sparkling') }
    menu.choice :Watir, -> { choose_test_framework('watir') }
    menu.choice :Quit, -> { exit }
  end
end
