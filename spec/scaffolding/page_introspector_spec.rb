# frozen_string_literal: true

require 'fileutils'
require_relative '../../lib/scaffolding/page_introspector'

RSpec.describe PageIntrospector do
  subject(:introspector) { described_class.new(page_file) }

  let(:tmp_dir) { 'tmp_introspector_test' }
  let(:page_file) { "#{tmp_dir}/login_page.rb" }

  before do
    FileUtils.mkdir_p(tmp_dir)
    File.write(page_file, <<~RUBY)
      class LoginPage < Page
        def url(_page)
          '/login'
        end

        def login(username, password)
          username_field.send_keys username
          password_field.send_keys password
          login_button.click
        end

        def welcome_message
          driver.find_element(css: '.welcome').text
        end

        private

        def username_field
          driver.find_element(id: 'username')
        end

        def password_field
          driver.find_element(id: 'password')
        end

        def login_button
          driver.find_element(id: 'login-btn')
        end
      end
    RUBY
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  it 'extracts class name' do
    expect(introspector.class_name).to eq('LoginPage')
  end

  it 'extracts public methods' do
    method_names = introspector.methods.map { |m| m[:name] }
    expect(method_names).to include('login')
    expect(method_names).to include('welcome_message')
  end

  it 'skips url method' do
    method_names = introspector.methods.map { |m| m[:name] }
    expect(method_names).not_to include('url')
  end

  it 'skips private methods' do
    method_names = introspector.methods.map { |m| m[:name] }
    expect(method_names).not_to include('username_field')
    expect(method_names).not_to include('password_field')
    expect(method_names).not_to include('login_button')
  end

  it 'extracts method parameters' do
    login_method = introspector.methods.find { |m| m[:name] == 'login' }
    expect(login_method[:params]).to eq(%w[username password])
  end

  it 'handles methods with no parameters' do
    welcome = introspector.methods.find { |m| m[:name] == 'welcome_message' }
    expect(welcome[:params]).to eq([])
  end
end
