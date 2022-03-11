require_relative 'file_generator'

module RubyRaider
  class CucumberFileGenerator < FileGenerator
    def self.generate_cucumber_files(name, automation)
      CommonFileGenerator.generate_common_files(name, 'cucumber')
      HelpersFileGenerator.generate_helper_files(name, automation, 'cucumber')
      generate_file('login.feature', "#{name}/features", example_feature)
      generate_file('login_steps.rb', "#{name}/features/step_definitions", example_steps)
      if automation == 'watir'
        WatirFileGenerator.generate_watir_files(name)
      else
        SeleniumFileGenerator.generate_selenium_files(name)
      end
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
