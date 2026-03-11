# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/adopter/project_analyzer'

RSpec.describe Adopter::ProjectAnalyzer do
  let(:project_dir) { 'tmp_analyzer_project' }

  before { FileUtils.mkdir_p(project_dir) }

  after { FileUtils.rm_rf(project_dir) }

  describe '#analyze' do
    context 'with a selenium + rspec project' do
      before do
        File.write("#{project_dir}/Gemfile", <<~GEMFILE)
          gem 'rspec'
          gem 'selenium-webdriver'
          gem 'faker'
          gem 'httparty'
        GEMFILE
        FileUtils.mkdir_p("#{project_dir}/pages")
        FileUtils.mkdir_p("#{project_dir}/spec")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < BasePage
            def login(username, password)
              driver.find_element(id: 'user').send_keys username
              driver.find_element(id: 'pass').send_keys password
              driver.find_element(id: 'submit').click
            end

            private

            def username_field
              driver.find_element(id: 'user')
            end
          end
        RUBY

        File.write("#{project_dir}/spec/login_spec.rb", <<~RUBY)
          describe 'Login' do
            let(:login_page) { LoginPage.new(driver) }

            it 'can log in with valid credentials' do
              expect(header).to eq 'Welcome'
            end

            it 'shows error with invalid credentials' do
              expect(error).to eq 'Invalid'
            end
          end
        RUBY
      end

      it 'returns a complete analysis hash' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis).to include(
          automation: 'selenium',
          framework: 'rspec',
          source_dsl: :selenium
        )
      end

      it 'discovers page objects' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:pages].length).to eq(1)
        expect(analysis[:pages].first).to include(
          class_name: 'LoginPage',
          base_class: 'BasePage'
        )
      end

      it 'extracts public methods from pages' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:pages].first[:methods]).to eq(['login'])
      end

      it 'discovers test files' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:tests].length).to eq(1)
        expect(analysis[:tests].first[:type]).to eq(:rspec)
      end

      it 'extracts test method names' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:tests].first[:test_methods]).to include(
          'can log in with valid credentials',
          'shows error with invalid credentials'
        )
      end

      it 'identifies custom gems' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:custom_gems]).to contain_exactly('faker', 'httparty')
      end
    end

    context 'with a capybara/site_prism project' do
      before do
        File.write("#{project_dir}/Gemfile", <<~GEMFILE)
          gem 'capybara'
          gem 'site_prism'
          gem 'rspec'
          gem 'selenium-webdriver'
        GEMFILE
        FileUtils.mkdir_p("#{project_dir}/pages")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < SitePrism::Page
            set_url '/login'
            element :email_field, '#email'
            element :password_field, '#password'
          end
        RUBY
      end

      it 'detects site_prism dsl' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:source_dsl]).to eq(:site_prism)
      end

      it 'detects capybara automation' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:automation]).to eq('capybara')
      end
    end

    context 'with a capybara DSL project (no site_prism)' do
      before do
        File.write("#{project_dir}/Gemfile", <<~GEMFILE)
          gem 'capybara'
          gem 'rspec'
        GEMFILE
        FileUtils.mkdir_p("#{project_dir}/pages")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < BasePage
            include Capybara::DSL

            def login(email, password)
              fill_in 'email', with: email
              fill_in 'password', with: password
              click_button 'Login'
            end
          end
        RUBY
      end

      it 'detects capybara dsl' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:source_dsl]).to eq(:capybara)
      end
    end

    context 'with a watir project' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'watir'\ngem 'rspec'\n")
        FileUtils.mkdir_p("#{project_dir}/pages")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < Page
            def login(username, password)
              browser.text_field(id: 'user').set username
              browser.button(id: 'submit').click
            end
          end
        RUBY
      end

      it 'detects watir dsl' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:source_dsl]).to eq(:watir)
      end
    end

    context 'with a minitest project' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'minitest'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/pages")
        FileUtils.mkdir_p("#{project_dir}/test")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < BasePage
            def login(u, p)
              driver.find_element(id: 'user').send_keys u
            end
          end
        RUBY

        File.write("#{project_dir}/test/test_login.rb", <<~RUBY)
          class TestLogin < Minitest::Test
            def test_successful_login
              assert_equal 'Welcome', header
            end

            def test_failed_login
              assert_equal 'Error', message
            end
          end
        RUBY
      end

      it 'discovers minitest files' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:tests].length).to eq(1)
        expect(analysis[:tests].first[:type]).to eq(:minitest)
      end

      it 'extracts minitest method names' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:tests].first[:test_methods]).to contain_exactly(
          'test_successful_login', 'test_failed_login'
        )
      end
    end

    context 'with a cucumber project' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'cucumber'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/pages")
        FileUtils.mkdir_p("#{project_dir}/features/step_definitions")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < BasePage
            def login(u, p)
              driver.find_element(id: 'user').send_keys u
            end
          end
        RUBY

        File.write("#{project_dir}/features/login.feature", <<~GHERKIN)
          Feature: Login

          Scenario: Successful login
            Given I am on the login page
            When I enter valid credentials
            Then I see the dashboard

          Scenario: Failed login
            Given I am on the login page
            When I enter invalid credentials
            Then I see an error
        GHERKIN

        File.write("#{project_dir}/features/step_definitions/login_steps.rb", <<~RUBY)
          Given('I am on the login page') do
            visit '/login'
          end

          When('I enter valid credentials') do
            fill_in 'email', with: 'test@test.com'
          end

          Then('I see the dashboard') do
            expect(page).to have_content 'Dashboard'
          end
        RUBY
      end

      it 'discovers feature files' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:features].length).to eq(1)
        expect(analysis[:features].first[:scenarios]).to eq(2)
      end

      it 'discovers step definitions' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:step_definitions].length).to eq(1)
        expect(analysis[:step_definitions].first[:steps]).to eq(3)
      end
    end

    context 'with an appium project' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'appium_lib'\ngem 'rspec'\n")
      end

      it 'raises MobileProjectError' do
        expect { described_class.new(project_dir).analyze }
          .to raise_error(Adopter::MobileProjectError, /Mobile.*cannot be adopted/)
      end
    end

    context 'with overrides' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/spec")
      end

      it 'applies overrides to detection' do
        analysis = described_class.new(project_dir, browser: 'firefox').analyze
        expect(analysis[:browser]).to eq('firefox')
      end
    end

    context 'with helpers' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/spec/support")

        File.write("#{project_dir}/spec/support/driver_setup.rb", <<~RUBY)
          module DriverHelper
            def driver
              @driver ||= Selenium::WebDriver.for :chrome
            end

            def create_driver
              Selenium::WebDriver.for :chrome
            end
          end
        RUBY
      end

      it 'discovers helpers with roles' do
        analysis = described_class.new(project_dir).analyze
        driver_helper = analysis[:helpers].find { |h| h[:role] == :driver }
        expect(driver_helper).not_to be_nil
        expect(driver_helper[:modules_defined]).to include('DriverHelper')
      end
    end

    context 'with no page objects' do
      before do
        File.write("#{project_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/spec")
      end

      it 'returns empty pages and raw dsl' do
        analysis = described_class.new(project_dir).analyze
        expect(analysis[:pages]).to eq([])
        expect(analysis[:source_dsl]).to eq(:raw)
      end
    end
  end
end
