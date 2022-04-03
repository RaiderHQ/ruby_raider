require_relative '../template'

class ExampleStepsTemplate < Template
  def body
    <<~EOF
          require_relative '../../page_objects/pages/login_page'

          Given("I'm a registered user on the login page") do
            LoginPage.visit
          end

          When('I login with my credentials') do
            LoginPage.login('aguspe', '12341234')
          end

          When('I can see the main page') do
            expect(LoginPage.header.customer_name).to eq 'Welcome back Agustin'
          end
    EOF
  end
end
