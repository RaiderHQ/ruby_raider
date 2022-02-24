require_relative 'common_file_generator'
require_relative 'file_generator'
require_relative 'watir_file_generator'

module RubyRaider
  class RspecFileGenerator < FileGenerator
    def self.generate_rspec_files(name, automation)
      if automation == 'watir'
        CommonFileGenerator.generate_common_files(name)
      WatirFileGenerator.generate_watir_files(name)
      generate_file('login_page.rb', "#{name}/spec", generate_example_spec)
      else
        pp 'here goes selenium'
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
                expect(LoginPage.customer_name).to eq 'Welcome back Agustin'
              end
            end

            describe 'A user cannot' do
              it 'login with the wrong credentials', :JIRA_123 do
                expect(LoginPage.customer_name).to eq 'Login or register'
              end
            end
          end
        end
      EOF
      spec.result(binding)
    end
  end
end
