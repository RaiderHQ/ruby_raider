# frozen_string_literal: true

require_relative '../template'

# Generates an rspec test file
class ExampleSpecTemplate < Template
  def examples
    if %w[selenium watir].include? automation
      <<-RUBY.chomp
  describe 'Login' do
    before(:each) do
      LoginPage.visit
    end

    it 'can login with valid credentials' do
      LoginPage.login('aguspe', '12341234')
      expect(LoginPage.header.customer_name).to eq 'Welcome back Agustin'
    end

    it 'cannot login with wrong credentials' do
      LoginPage.login('aguspe', 'wrongPassword')
      expect(LoginPage.header.customer_name).to be_empty
    end
  end
      RUBY
    else
      <<-RUBY.chomp
  describe 'Login' do#{'          '}
    it 'Login with valid credentials' do
      HomePage.go_to_login
      LoginPage.login('alice', 'mypassword')
      expect(ConfirmationPage.login_message).to eq 'You are logged in as alice'
    end
  end
      RUBY
    end
  end

  def requirements
    return if %w[selenium watir].include? automation

    <<~RUBY.chomp
      require_relative '../page_objects/pages/confirmation_page'
      require_relative '../page_objects/pages/home_page'
    RUBY
  end

  def body
    <<~RUBY
      #{requirements}
      require_relative 'base_spec'
      require_relative '../page_objects/pages/login_page'

      class LoginSpec < BaseSpec
      #{examples}
      end
    RUBY
  end
end
