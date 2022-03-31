require_relative '../template'

class GemfileTemplate < Template
  def body
    if @framework == 'cucumber'
      allure_cucumber = "gem 'allure-cucumber'"
      rspec = "gem 'rspec'"
    end

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
          #{rspec}
          gem 'selenium-webdriver'
          gem 'watir'
          gem 'webdrivers'
    EOF
  end
end
