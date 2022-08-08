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

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'

    select_test_framework(automation)
  end

  def set_framework(automation, framework)
    add_generator framework.capitalize
    generators.each { |generator| invoke_generator(automation, framework, generator) }
    system "cd #{name} && gem install bundler && bundle install"
  end

  def choose_mobile_platform
    prompt.select('Please select your mobile platform') do |menu|
      menu.choice :iOS, -> { choose_test_framework 'appium_ios' }
      menu.choice :Android, -> { error_handling('Android') }
      menu.choice :Cross_Platform, -> { error_handling('Cross Platform') }
      menu.choice :Quit, -> { exit }
    end
  end

  protected

  def add_generator(*opts)
    opts.each { |opt| @generators.push opt }
  end

  private

  def framework_choice(framework, automation_type)
    set_framework(automation_type, framework.downcase)
    prompt.say("You have chosen to use #{framework} with #{automation_type}")
  end

  def error_handling(platform)
    pp "#{platform} appium is coming soon. Thank you for the interest"
  end

  def select_test_framework(automation)
    prompt.select('Please select your test framework') do |menu|
      menu.choice :Cucumber, -> { framework_choice('Cucumber', automation) }
      menu.choice :Rspec, -> { framework_choice('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  def invoke_generator(automation, framework, generator)
    Object.const_get("#{generator}Generator").new([automation, framework, name]).invoke_all
  end
end
