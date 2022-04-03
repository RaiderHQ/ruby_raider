require_relative '../template'

class ExampleSpecTemplate < Template
  def body
    <<~EOF
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
  end
end
