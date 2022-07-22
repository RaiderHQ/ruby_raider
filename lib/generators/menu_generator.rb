# frozen_string_literal: true

require 'highline'
require_relative 'automation_generator'
require_relative 'common_generator'
require_relative 'cucumber_generator'
require_relative 'helper_generator'
require_relative 'rspec_generator'

class MenuGenerator
  attr_reader :cli, :name, :generators

  def initialize(project_name)
    @cli = HighLine.new
    @name = project_name
    @generators = %w[Automation Common Helpers]
  end

  def generate_choice_menu
    @cli.choose do |menu|
      menu.prompt = 'Please select your automation framework'
      menu.choice('Selenium') { choose_test_framework('selenium') }
      menu.choice('Watir') { choose_test_framework('watir') }
      menu.choice('Appium') { choose_test_framework('appium') }
      menu.choice('Quit') { exit }
    end
  end

  def choose_test_framework(automation)
    system('clear') || system('cls')
    sleep 0.3
    automation = automation == 'appium' ? choose_mobile_platform : automation
    select_test_framework(automation)
  end

  def set_framework(automation, framework)
    add_generator framework.capitalize
    generators.each { |generator| invoke_generator(automation, framework, generator) }
    system "cd #{name} && gem install bundler && bundle install"
  end

  def choose_mobile_platform
    @cli.choose do |menu|
      menu.prompt = 'Please select your mobile platform'
      menu.choice('iOS') { 'appium_ios' }
      error_handling(menu, 'Android')
      error_handling(menu, 'Cross Platform')
      menu.choice('Quit') { exit }
    end
  end

  protected

  def add_generator(*opts)
    opts.each { |opt| @generators.push opt }
  end

  private

  def framework_choice(invoker, framework, automation_type)
    invoker.choice(framework) do
      set_framework(automation_type, framework.downcase)
      @cli.say("You have chosen to use #{framework} with #{automation_type}")
    end
  end

  def error_handling(invoker, platform)
    invoker.choice(platform) do
      pp "#{platform} appium is coming soon. Thank you for the interest"
      exit
    end
  end

  def select_test_framework(automation)
    @cli.choose do |menu|
      menu.prompt = 'Please select your test framework'
      framework_choice(menu, 'Rspec', automation)
      framework_choice(menu, 'Cucumber', automation)
      menu.choice('Quit') { exit }
    end
  end

  def invoke_generator(automation, framework, generator)
    Object.const_get("#{generator}Generator").new([automation, framework, name]).invoke_all
  end
end
