# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative '../../lib/adopter/adopt_menu'

describe 'Adopt matrix: all target combinations' do
  source_dir = 'tmp_adopt_matrix_source'

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FileUtils.mkdir_p("#{source_dir}/pages")
    FileUtils.mkdir_p("#{source_dir}/spec")
    FileUtils.mkdir_p("#{source_dir}/features/step_definitions")

    File.write("#{source_dir}/Gemfile", <<~GEMFILE)
      gem 'rspec'
      gem 'selenium-webdriver'
      gem 'faker'
      gem 'dotenv'
    GEMFILE

    File.write("#{source_dir}/pages/login_page.rb", <<~RUBY)
      class LoginPage < BasePage
        def login(user, pass)
          driver.find_element(id: 'user').send_keys user
          driver.find_element(id: 'pass').send_keys pass
          driver.find_element(id: 'submit').click
        end
      end
    RUBY

    File.write("#{source_dir}/pages/dashboard_page.rb", <<~RUBY)
      class DashboardPage < BasePage
        def welcome_message
          driver.find_element(css: '.welcome').text
        end
      end
    RUBY

    File.write("#{source_dir}/spec/login_spec.rb", <<~RUBY)
      describe 'Login' do
        it 'can log in' do
          page = LoginPage.new(driver)
          page.login('admin', 'secret')
          expect(page).to be_truthy
        end
      end
    RUBY

    File.write("#{source_dir}/spec/dashboard_spec.rb", <<~RUBY)
      describe 'Dashboard' do
        it 'shows welcome' do
          expect(true).to eq true
        end
      end
    RUBY

    File.write("#{source_dir}/features/login.feature", <<~GHERKIN)
      Feature: Login
        Scenario: Valid login
          Given I am on the login page
          When I log in with valid credentials
          Then I see the dashboard
    GHERKIN

    File.write("#{source_dir}/features/step_definitions/login_steps.rb", <<~RUBY)
      Given('I am on the login page') do
        @page = LoginPage.new(driver)
      end

      When('I log in with valid credentials') do
        @page.login('admin', 'secret')
      end

      Then('I see the dashboard') do
        expect(true).to eq true
      end
    RUBY

    # Generate all 9 combinations
    Adopter::AdoptMenu::WEB_AUTOMATIONS.each do |automation|
      Adopter::AdoptMenu::TEST_FRAMEWORKS.each do |framework|
        output = "tmp_adopt_matrix_#{automation}_#{framework}"
        Adopter::AdoptMenu.adopt(
          source_path: source_dir,
          output_path: output,
          target_automation: automation,
          target_framework: framework
        )
      end
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FileUtils.rm_rf(source_dir)
    Adopter::AdoptMenu::WEB_AUTOMATIONS.each do |automation|
      Adopter::AdoptMenu::TEST_FRAMEWORKS.each do |framework|
        FileUtils.rm_rf("tmp_adopt_matrix_#{automation}_#{framework}")
      end
    end
  end

  # --- Shared examples ---

  shared_examples 'valid adopted project structure' do |output_dir|
    it 'creates Gemfile' do
      expect(File).to exist("#{output_dir}/Gemfile")
    end

    it 'creates Rakefile' do
      expect(File).to exist("#{output_dir}/Rakefile")
    end

    it 'creates Readme.md' do
      expect(File).to exist("#{output_dir}/Readme.md")
    end

    it 'creates .rubocop.yml' do
      expect(File).to exist("#{output_dir}/.rubocop.yml")
    end

    it 'creates config/config.yml' do
      expect(File).to exist("#{output_dir}/config/config.yml")
    end

    it 'creates page_objects directory' do
      expect(File).to exist("#{output_dir}/page_objects/pages")
    end

    it 'creates abstract page' do
      expect(File).to exist("#{output_dir}/page_objects/abstract/page.rb")
    end
  end

  shared_examples 'converted pages' do |output_dir|
    it 'converts login page into raider path' do
      expect(File).to exist("#{output_dir}/page_objects/pages/login.rb")
    end

    it 'converts dashboard page into raider path' do
      expect(File).to exist("#{output_dir}/page_objects/pages/dashboard.rb")
    end

    it 'adds frozen_string_literal to login page' do
      page = File.read("#{output_dir}/page_objects/pages/login.rb")
      expect(page).to include('# frozen_string_literal: true')
    end

    it 'updates login page base class to Page' do
      page = File.read("#{output_dir}/page_objects/pages/login.rb")
      expect(page).to include('class LoginPage < Page')
    end

    it 'updates dashboard page base class to Page' do
      page = File.read("#{output_dir}/page_objects/pages/dashboard.rb")
      expect(page).to include('class DashboardPage < Page')
    end
  end

  shared_examples 'merged gems' do |output_dir|
    it 'includes custom gems from source' do
      gemfile = File.read("#{output_dir}/Gemfile")
      expect(gemfile).to include("gem 'faker'")
      expect(gemfile).to include("gem 'dotenv'")
    end

    it 'does not duplicate framework gems' do
      gemfile = File.read("#{output_dir}/Gemfile")
      occurrences = gemfile.scan("gem 'rspec'").length + gemfile.scan("gem 'selenium-webdriver'").length
      expect(occurrences).to be <= 2
    end
  end

  shared_examples 'allure helper' do |output_dir|
    it 'creates allure_helper.rb' do
      expect(File).to exist("#{output_dir}/helpers/allure_helper.rb")
    end

    it 'allure_helper defines AllureHelper module' do
      content = File.read("#{output_dir}/helpers/allure_helper.rb")
      expect(content).to include('module AllureHelper')
    end
  end

  # --- Automation-specific helpers ---

  shared_examples 'selenium helpers' do |output_dir|
    it 'creates driver_helper.rb' do
      expect(File).to exist("#{output_dir}/helpers/driver_helper.rb")
    end

    it 'driver_helper defines DriverHelper module' do
      content = File.read("#{output_dir}/helpers/driver_helper.rb")
      expect(content).to include('module DriverHelper')
    end

    it 'driver_helper requires selenium-webdriver' do
      content = File.read("#{output_dir}/helpers/driver_helper.rb")
      expect(content).to include("require 'selenium-webdriver'")
    end

    it 'does not create browser_helper.rb' do
      expect(File).not_to exist("#{output_dir}/helpers/browser_helper.rb")
    end

    it 'does not create capybara_helper.rb' do
      expect(File).not_to exist("#{output_dir}/helpers/capybara_helper.rb")
    end
  end

  shared_examples 'watir helpers' do |output_dir|
    it 'creates browser_helper.rb' do
      expect(File).to exist("#{output_dir}/helpers/browser_helper.rb")
    end

    it 'browser_helper defines BrowserHelper module' do
      content = File.read("#{output_dir}/helpers/browser_helper.rb")
      expect(content).to include('module BrowserHelper')
    end

    it 'browser_helper requires watir' do
      content = File.read("#{output_dir}/helpers/browser_helper.rb")
      expect(content).to include("require 'watir'")
    end

    it 'does not create driver_helper.rb' do
      expect(File).not_to exist("#{output_dir}/helpers/driver_helper.rb")
    end

    it 'does not create capybara_helper.rb' do
      expect(File).not_to exist("#{output_dir}/helpers/capybara_helper.rb")
    end
  end

  shared_examples 'capybara helpers' do |output_dir|
    it 'creates capybara_helper.rb' do
      expect(File).to exist("#{output_dir}/helpers/capybara_helper.rb")
    end

    it 'capybara_helper defines CapybaraHelper module' do
      content = File.read("#{output_dir}/helpers/capybara_helper.rb")
      expect(content).to include('module CapybaraHelper')
    end

    it 'capybara_helper requires capybara' do
      content = File.read("#{output_dir}/helpers/capybara_helper.rb")
      expect(content).to include("require 'capybara'")
    end

    it 'does not create driver_helper.rb' do
      expect(File).not_to exist("#{output_dir}/helpers/driver_helper.rb")
    end

    it 'does not create browser_helper.rb' do
      expect(File).not_to exist("#{output_dir}/helpers/browser_helper.rb")
    end
  end

  # --- Framework-specific structure ---

  shared_examples 'rspec structure' do |output_dir|
    it 'creates spec directory' do
      expect(File).to exist("#{output_dir}/spec")
    end

    it 'creates spec_helper.rb' do
      expect(File).to exist("#{output_dir}/helpers/spec_helper.rb")
    end

    it 'spec_helper defines SpecHelper module' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include('module SpecHelper')
    end

    it 'converts source tests into spec directory' do
      expect(File).to exist("#{output_dir}/spec/login_spec.rb")
    end

    it 'converts dashboard test into spec directory' do
      expect(File).to exist("#{output_dir}/spec/dashboard_spec.rb")
    end

    it 'does not create test directory' do
      expect(Dir).not_to exist("#{output_dir}/test")
    end

    it 'does not create features directory with step definitions' do
      expect(File).not_to exist("#{output_dir}/features/step_definitions/login_steps.rb")
    end
  end

  shared_examples 'cucumber structure' do |output_dir|
    it 'creates features directory' do
      expect(File).to exist("#{output_dir}/features")
    end

    it 'creates features/support/env.rb' do
      expect(File).to exist("#{output_dir}/features/support/env.rb")
    end

    it 'creates cucumber.yml' do
      expect(File).to exist("#{output_dir}/cucumber.yml")
    end

    it 'copies feature files' do
      expect(File).to exist("#{output_dir}/features/login.feature")
    end

    it 'feature files contain Gherkin keywords' do
      content = File.read("#{output_dir}/features/login.feature")
      expect(content).to include('Feature:')
      expect(content).to include('Scenario:')
    end

    it 'copies step definitions' do
      expect(File).to exist("#{output_dir}/features/step_definitions/login_steps.rb")
    end

    it 'does not create spec directory with converted tests' do
      expect(File).not_to exist("#{output_dir}/spec/login_spec.rb")
    end

    it 'does not create test directory' do
      expect(Dir).not_to exist("#{output_dir}/test")
    end
  end

  shared_examples 'minitest structure' do |output_dir|
    it 'creates test directory' do
      expect(File).to exist("#{output_dir}/test")
    end

    it 'creates test_helper.rb' do
      expect(File).to exist("#{output_dir}/helpers/test_helper.rb")
    end

    it 'test_helper defines TestHelper module' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include('module TestHelper')
    end

    it 'test_helper requires minitest/autorun' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include("require 'minitest/autorun'")
    end

    it 'converts source tests into test directory' do
      expect(File).to exist("#{output_dir}/test/test_login.rb")
    end

    it 'does not create spec directory with converted tests' do
      expect(File).not_to exist("#{output_dir}/spec/login_spec.rb")
    end

    it 'does not create features directory with step definitions' do
      expect(File).not_to exist("#{output_dir}/features/step_definitions/login_steps.rb")
    end
  end

  # --- Automation-framework helper wiring ---

  shared_examples 'rspec wired to selenium' do |output_dir|
    it 'spec_helper includes DriverHelper' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include('DriverHelper')
    end

    it 'spec_helper requires driver_helper' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include("require_relative 'driver_helper'")
    end
  end

  shared_examples 'rspec wired to watir' do |output_dir|
    it 'spec_helper includes BrowserHelper' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include('BrowserHelper')
    end

    it 'spec_helper requires browser_helper' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include("require_relative 'browser_helper'")
    end
  end

  shared_examples 'rspec wired to capybara' do |output_dir|
    it 'spec_helper includes Capybara::DSL' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include('Capybara::DSL')
    end

    it 'spec_helper requires capybara_helper' do
      content = File.read("#{output_dir}/helpers/spec_helper.rb")
      expect(content).to include("require_relative 'capybara_helper'")
    end
  end

  shared_examples 'minitest wired to selenium' do |output_dir|
    it 'test_helper includes DriverHelper' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include('DriverHelper')
    end

    it 'test_helper requires driver_helper' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include("require_relative 'driver_helper'")
    end
  end

  shared_examples 'minitest wired to watir' do |output_dir|
    it 'test_helper includes BrowserHelper' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include('BrowserHelper')
    end

    it 'test_helper requires browser_helper' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include("require_relative 'browser_helper'")
    end
  end

  shared_examples 'minitest wired to capybara' do |output_dir|
    it 'test_helper includes Capybara::DSL' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include('Capybara::DSL')
    end

    it 'test_helper requires capybara_helper' do
      content = File.read("#{output_dir}/helpers/test_helper.rb")
      expect(content).to include("require_relative 'capybara_helper'")
    end
  end

  # === The 9 combinations (3 automations x 3 frameworks) ===

  # --- Selenium ---

  context 'selenium + rspec' do
    output = 'tmp_adopt_matrix_selenium_rspec'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'selenium helpers', output
    it_behaves_like 'rspec structure', output
    it_behaves_like 'rspec wired to selenium', output
  end

  context 'selenium + cucumber' do
    output = 'tmp_adopt_matrix_selenium_cucumber'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'selenium helpers', output
    it_behaves_like 'cucumber structure', output
  end

  context 'selenium + minitest' do
    output = 'tmp_adopt_matrix_selenium_minitest'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'selenium helpers', output
    it_behaves_like 'minitest structure', output
    it_behaves_like 'minitest wired to selenium', output
  end

  # --- Capybara ---

  context 'capybara + rspec' do
    output = 'tmp_adopt_matrix_capybara_rspec'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'capybara helpers', output
    it_behaves_like 'rspec structure', output
    it_behaves_like 'rspec wired to capybara', output
  end

  context 'capybara + cucumber' do
    output = 'tmp_adopt_matrix_capybara_cucumber'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'capybara helpers', output
    it_behaves_like 'cucumber structure', output
  end

  context 'capybara + minitest' do
    output = 'tmp_adopt_matrix_capybara_minitest'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'capybara helpers', output
    it_behaves_like 'minitest structure', output
    it_behaves_like 'minitest wired to capybara', output
  end

  # --- Watir ---

  context 'watir + rspec' do
    output = 'tmp_adopt_matrix_watir_rspec'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'watir helpers', output
    it_behaves_like 'rspec structure', output
    it_behaves_like 'rspec wired to watir', output
  end

  context 'watir + cucumber' do
    output = 'tmp_adopt_matrix_watir_cucumber'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'watir helpers', output
    it_behaves_like 'cucumber structure', output
  end

  context 'watir + minitest' do
    output = 'tmp_adopt_matrix_watir_minitest'
    it_behaves_like 'valid adopted project structure', output
    it_behaves_like 'converted pages', output
    it_behaves_like 'merged gems', output
    it_behaves_like 'allure helper', output
    it_behaves_like 'watir helpers', output
    it_behaves_like 'minitest structure', output
    it_behaves_like 'minitest wired to watir', output
  end
end
