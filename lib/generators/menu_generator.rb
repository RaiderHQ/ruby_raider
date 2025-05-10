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

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'

    select_test_framework(automation)
  end

  def set_up_framework(options)
    structure = {
      automation: options[:automation],
      framework: options[:framework],
      ci_platform: options[:ci_platform],
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
      menu.choice :Cucumber, -> { select_ci_platform('Cucumber', automation) }
      menu.choice :Rspec, -> { select_ci_platform('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  FrameworkOptions = Struct.new(:automation, :framework, :ci_platform)

  def create_framework_options(params)
    FrameworkOptions.new(params[:automation], params[:framework], params[:ci_platform])
  end

  def create_framework(framework, automation_type, ci_platform = nil)
    options = create_framework_options(automation: automation_type,
                                       framework: framework.downcase,
                                       ci_platform:)

    puts 'Chosen Options:'
    puts "  Automation Type: #{options[:automation]}"
    puts "  Framework: #{options[:framework]}"
    puts "  CI Platform: #{options[:ci_platform]}" if options[:ci_platform]

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
    automation_options(menu)
    menu.choice :Quit, -> { exit }
  end

  def automation_options(menu)
    menu.choice :Selenium, -> { choose_test_framework('selenium') }
    menu.choice :Appium, -> { choose_test_framework('appium') }
    menu.choice :Watir, -> { choose_test_framework('watir') }
    menu.choice :Applitools, -> { choose_test_framework('applitools') }
    menu.choice :Axe, -> { choose_test_framework('axe') }
  end

  def select_ci_platform(framework, automation)
    prompt.select('Would you like to configure CI?') do |menu|
      menu.choice :'Github Actions', -> { create_framework(framework, automation, 'github') }
      menu.choice :'Gitlab CI/CD', -> { create_framework(framework, automation, 'gitlab') }
      menu.choice :No, -> { create_framework(framework, automation) }
      menu.choice :Quit, -> { exit }
    end
  end
end
