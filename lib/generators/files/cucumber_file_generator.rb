require_relative 'file_generator'

module RubyRaider
  class CucumberFileGenerator < FileGenerator
    def self.generate_selenium_files(name)
      generate_file('login_page.feature', "#{name}/features", example_feature)
      generate_file('login_steps.rb', "#{name}/features/steps_definitions", example_steps)
    end

    def self.example_feature
      gemfile = ERB.new <<~EOF
        Feature: Login Page

        Scenario:
          Given I'm a registered user
          When I login with my credentials
          Then I can see the main page

      EOF
      gemfile.result(binding)
    end

    def self.example_steps
      gemfile = ERB.new <<~EOF
        require_relative '../../page_objects/pages/login_page'

        Given("I'm a registered user on the login page") do
          LoginPage.visit
        end

        When('I login with my credentials') do
          LoginPage.login('aguspe', '12341234')
        end

        When('Then I can see the main page') do
          expect(LoginPage.header.customer_name).to eq 'Welcome back Agustin'
        end
      EOF
      gemfile.result(binding)
    end
  end
end
