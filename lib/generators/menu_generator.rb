# frozen_string_literal: true

require 'tty-prompt'
require_relative 'automation_generator'
require_relative 'common_generator'
require_relative 'cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec_generator'

class MenuGenerator
  attr_reader :prompt, :name, :generators

  def initialize(project_name)
    @prompt = TTY::Prompt.new
    @name = project_name
    @generators = %w[Automation Common Helpers]
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
      menu.choice :Yes, -> { true  }
      menu.choice :No, -> { false }
      menu.choice :Quit, -> { exit }
    end
  end

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'

    select_test_framework(automation)
  end

  def set_up_framework(automation, framework, visual_automation)
    generate_framework(automation, framework, visual_automation)
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

  def generate_framework(automation, framework, visual_automation)
    add_generator framework.capitalize
    generators.each { |generator| invoke_generator(automation, framework, generator, visual_automation) }
  end

  protected

  def add_generator(*opts)
    opts.each { |opt| @generators.push opt }
  end

  private

  def framework_choice(framework, automation_type)
    visual_automation = choose_visual_automation if %w[selenium watir].include?(automation_type) && framework == 'Rspec'

    set_up_framework(automation_type, framework.downcase, visual_automation)
    prompt.say("You have chosen to use #{framework} with #{automation_type}")
  end

  def select_test_framework(automation)
    prompt.select('Please select your test framework') do |menu|
      menu.choice :Cucumber, -> { framework_choice('Cucumber', automation) }
      menu.choice :Rspec, -> { framework_choice('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  def invoke_generator(automation, framework, generator, visual_automation)
    Object.const_get("#{generator}Generator").new([automation, framework, name, visual_automation]).invoke_all
  end
end
