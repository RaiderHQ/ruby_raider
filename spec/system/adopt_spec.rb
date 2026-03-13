# frozen_string_literal: true

require 'fileutils'
require_relative '../../lib/adopter/adopt_menu'
require_relative 'support/system_test_helper'

describe 'Adopt end-to-end' do
  include SystemTestHelper

  let(:source_dir) { "tmp_adopt_e2e_source_#{automation}" }
  let(:output_dir) { "tmp_adopt_e2e_#{automation}_#{framework}" }

  before do
    FileUtils.mkdir_p("#{source_dir}/pages")
    FileUtils.mkdir_p("#{source_dir}/spec")

    File.write("#{source_dir}/Gemfile", <<~GEMFILE)
      gem 'rspec'
      gem 'selenium-webdriver'
      gem 'faker'
    GEMFILE

    File.write("#{source_dir}/pages/login_page.rb", <<~RUBY)
      class LoginPage < BasePage
        def login(user, pass)
          driver.find_element(id: 'user').send_keys user
        end
      end
    RUBY

    File.write("#{source_dir}/spec/login_spec.rb", <<~RUBY)
      describe 'Login' do
        it 'can log in' do
          expect(true).to eq true
        end
      end
    RUBY
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(output_dir)
  end

  shared_examples 'valid adopted project' do
    it 'creates a complete raider project structure' do
      expect(File).to exist("#{output_dir}/Gemfile")
      expect(File).to exist("#{output_dir}/Rakefile")
      expect(File).to exist("#{output_dir}/Readme.md")
      expect(File).to exist("#{output_dir}/.rubocop.yml")
    end

    it 'converts pages into raider paths' do
      expect(File).to exist("#{output_dir}/page_objects/pages/login.rb")
    end

    it 'adds frozen_string_literal to converted pages' do
      page = File.read("#{output_dir}/page_objects/pages/login.rb")
      expect(page).to include('# frozen_string_literal: true')
    end

    it 'updates base class to Page' do
      page = File.read("#{output_dir}/page_objects/pages/login.rb")
      expect(page).to include('class LoginPage < Page')
    end

    it 'merges custom gems into Gemfile' do
      gemfile = File.read("#{output_dir}/Gemfile")
      expect(gemfile).to include("gem 'faker'")
    end
  end

  context 'selenium to selenium (identity conversion)' do
    let(:automation) { 'selenium' }
    let(:framework) { 'rspec' }

    before do
      Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: output_dir,
        target_automation: 'selenium', target_framework: 'rspec'
      )
    end

    include_examples 'valid adopted project'

    it 'generates rspec test files' do
      expect(File).to exist("#{output_dir}/spec")
    end

    it 'generates selenium helpers' do
      expect(File).to exist("#{output_dir}/helpers/driver_helper.rb")
    end

    it 'converts page instantiation to use driver' do
      result = Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: "#{output_dir}_check",
        target_automation: 'selenium', target_framework: 'rspec'
      )

      page = result[:plan].converted_pages.first.content
      expect(page).not_to include('LoginPage.new(browser)')

      FileUtils.rm_rf("#{output_dir}_check")
    end
  end

  context 'selenium to capybara' do
    let(:automation) { 'capybara' }
    let(:framework) { 'rspec' }

    before do
      Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: output_dir,
        target_automation: 'capybara', target_framework: 'rspec'
      )
    end

    include_examples 'valid adopted project'

    it 'generates capybara helpers' do
      expect(File).to exist("#{output_dir}/helpers/capybara_helper.rb")
    end

    it 'does not generate driver_helper' do
      expect(File).not_to exist("#{output_dir}/helpers/driver_helper.rb")
    end
  end

  context 'selenium to watir + minitest' do
    let(:automation) { 'watir' }
    let(:framework) { 'minitest' }

    before do
      Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: output_dir,
        target_automation: 'watir', target_framework: 'minitest'
      )
    end

    include_examples 'valid adopted project'

    it 'generates watir helpers' do
      expect(File).to exist("#{output_dir}/helpers/browser_helper.rb")
    end

    it 'generates minitest test helper' do
      expect(File).to exist("#{output_dir}/helpers/test_helper.rb")
    end

    it 'generates minitest test directory' do
      expect(File).to exist("#{output_dir}/test")
    end
  end

  context 'selenium to selenium + cucumber' do
    let(:automation) { 'selenium' }
    let(:framework) { 'cucumber' }

    before do
      FileUtils.mkdir_p("#{source_dir}/features/step_definitions")
      File.write("#{source_dir}/features/login.feature", <<~GHERKIN)
        Feature: Login
        Scenario: Valid login
          Given I am on the login page
      GHERKIN
      File.write("#{source_dir}/features/step_definitions/login_steps.rb", <<~RUBY)
        Given('I am on the login page') do
          @page = LoginPage.new(driver)
        end
      RUBY
      File.write("#{source_dir}/Gemfile", "gem 'cucumber'\ngem 'selenium-webdriver'\ngem 'faker'\n")

      Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: output_dir,
        target_automation: 'selenium', target_framework: 'cucumber'
      )
    end

    include_examples 'valid adopted project'

    it 'copies feature files' do
      expect(File).to exist("#{output_dir}/features/login.feature")
    end

    it 'converts step definitions' do
      expect(File).to exist("#{output_dir}/features/step_definitions/login_steps.rb")
    end

    it 'generates cucumber support files' do
      expect(File).to exist("#{output_dir}/features/support/env.rb")
    end
  end

  context 'with config overrides' do
    let(:automation) { 'selenium' }
    let(:framework) { 'rspec' }

    it 'applies browser and url overrides' do
      Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: output_dir,
        target_automation: 'selenium', target_framework: 'rspec',
        browser: 'firefox', url: 'https://example.com'
      )

      config = YAML.safe_load(File.read("#{output_dir}/config/config.yml"), permitted_classes: [Symbol])
      expect(config['browser']).to eq('firefox')
      expect(config['url']).to eq('https://example.com')
    end
  end

  context 'with CI platform' do
    let(:automation) { 'selenium' }
    let(:framework) { 'rspec' }

    it 'generates github CI configuration' do
      Adopter::AdoptMenu.adopt(
        source_path: source_dir, output_path: output_dir,
        target_automation: 'selenium', target_framework: 'rspec',
        ci_platform: 'github'
      )

      expect(File).to exist("#{output_dir}/.github")
    end
  end
end
