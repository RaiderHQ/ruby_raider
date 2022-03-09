require_relative 'common_file_generator'
require_relative 'file_generator'
require_relative 'helpers_file_generator'
require_relative 'selenium_file_generator'
require_relative 'watir_file_generator'

module RubyRaider
  class RspecFileGenerator < FileGenerator
    def self.generate_rspec_files(name, automation)
      CommonFileGenerator.generate_common_files(name)
      HelpersFileGenerator.generate_helper_files(name, automation)
      generate_file('login_page_spec.rb', "#{name}/spec", generate_example_spec)
      generate_file('base_spec.rb', "#{name}/spec", generate_base_spec)
      if automation == 'watir'
        WatirFileGenerator.generate_watir_files(name)
      else
        SeleniumFileGenerator.generate_selenium_files(name)
      end
    end

    def self.generate_example_spec
      spec = ERB.new <<~EOF
        require_relative 'base_spec'
        require_relative '../page_objects/pages/login_page'

        class LoginSpec < BaseSpec
          context 'On the Login Page' do

            before(:each) do
              LoginPage.visit
            end

            describe 'A user can' do
              it 'login with the right credentials', :JIRA_123 do
                LoginPage.login('aguspe', '12341234')
                expect(LoginPage.header.customer_name).to eq 'Welcome back Agustin'
              end
            end

            describe 'A user cannot' do
              it 'login with the wrong credentials', :JIRA_123 do
                LoginPage.login('aguspe', 'wrongPassword')
                expect(LoginPage.header.customer_name).to be_empty
              end
            end
          end
        end
      EOF
      spec.result(binding)
    end

    def self.generate_base_spec
      spec = ERB.new <<~EOF
         require_relative '../helpers/raider'

        class BaseSpec
          include Raider::SpecHelper
        end
      EOF
      spec.result(binding)
    end
  end
end
