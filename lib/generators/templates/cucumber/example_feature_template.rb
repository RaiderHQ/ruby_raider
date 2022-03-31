require_relative '../template'

class ExampleFeatureTemplate < Template
  def body
    <<~EOF
      Feature: Login Page

      Scenario: A user can login
        Given I'm a registered user on the login page
        When I login with my credentials
        Then I can see the main page

    EOF
  end
end
