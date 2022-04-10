require_relative '../template'

class GemfileTemplate < Template
  def automation_gems
    case @automation
    when 'watir'
      <<~EOF
        gem 'selenium-webdriver'
        gem 'watir'
      EOF
    when 'selenium'
      "gem 'selenium-webdriver'"
    else
      <<~EOF
        gem 'appium_lib'
        gem 'appium_console'
      EOF
    end
  end

  def webdrivers
    "gem 'webdrivers'" if %w[selenium watir].include?(@automation)
  end

  def allure_cucumber
    "gem 'allure-cucumber'" if @framework == 'cucumber'
  end

  def rspec_gem
    "gem 'rspec'" if @framework == 'cucumber'
  end

  def body
    <<~EOF
      # frozen_string_literal: true

      source 'https://rubygems.org'

      gem 'activesupport'
      gem 'allure-rspec'
      gem 'allure-ruby-commons'
      #{allure_cucumber}
      gem 'parallel_split_test'
      gem 'parallel_tests'
      gem 'rake'
      gem '#{@framework}'
      #{rspec_gem}
      #{automation_gems}
      #{webdrivers}
    EOF
  end
end
