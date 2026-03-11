# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/adopter/project_analyzer'
require_relative '../../lib/adopter/plan_builder'

RSpec.describe Adopter::PlanBuilder do
  let(:project_dir) { 'tmp_plan_builder_project' }

  before { FileUtils.mkdir_p(project_dir) }

  after { FileUtils.rm_rf(project_dir) }

  describe '#build' do
    context 'with a selenium + rspec project converting to same' do
      let(:params) do
        {
          source_path: project_dir,
          output_path: 'my_raider_project',
          target_automation: 'selenium',
          target_framework: 'rspec',
          ci_platform: 'github'
        }
      end

      before do
        File.write("#{project_dir}/Gemfile", <<~GEMFILE)
          gem 'rspec'
          gem 'selenium-webdriver'
          gem 'faker'
        GEMFILE
        FileUtils.mkdir_p("#{project_dir}/pages")
        FileUtils.mkdir_p("#{project_dir}/spec")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < BasePage
            def login(user, pass)
              driver.find_element(id: 'user').send_keys user
            end
          end
        RUBY

        File.write("#{project_dir}/spec/login_spec.rb", <<~RUBY)
          describe 'Login' do
            it 'can log in' do
              expect(result).to eq 'ok'
            end
          end
        RUBY
      end

      it 'builds a valid migration plan' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan).to be_a(Adopter::MigrationPlan)
        expect(plan.source_path).to eq(project_dir)
        expect(plan.output_path).to eq('my_raider_project')
        expect(plan.target_automation).to eq('selenium')
        expect(plan.target_framework).to eq('rspec')
      end

      it 'builds correct skeleton structure' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.skeleton_structure).to eq(
          automation: 'selenium',
          framework: 'rspec',
          name: 'my_raider_project',
          ci_platform: 'github'
        )
      end

      it 'converts pages with raider paths' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.converted_pages.length).to eq(1)
        page = plan.converted_pages.first
        expect(page.output_path).to eq('my_raider_project/page_objects/pages/login.rb')
        expect(page.source_file).to eq('pages/login_page.rb')
      end

      it 'converts tests with raider paths' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.converted_tests.length).to eq(1)
        test = plan.converted_tests.first
        expect(test.output_path).to eq('my_raider_project/spec/login_spec.rb')
      end

      it 'identifies custom gems' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.gemfile_additions).to eq(['faker'])
      end

      it 'adds frozen_string_literal when missing' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        page_content = plan.converted_pages.first.content
        expect(page_content).to include('frozen_string_literal: true')
      end
    end

    context 'converting to minitest output paths' do
      let(:params) do
        {
          source_path: project_dir,
          output_path: 'output',
          target_automation: 'selenium',
          target_framework: 'minitest'
        }
      end

      before do
        File.write("#{project_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/spec")

        File.write("#{project_dir}/spec/login_spec.rb", <<~RUBY)
          describe 'Login' do
            it 'works' do
              expect(true).to be true
            end
          end
        RUBY
      end

      it 'generates minitest-style output paths' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        test = plan.converted_tests.first
        expect(test.output_path).to eq('output/test/test_login.rb')
      end
    end

    context 'converting to cucumber' do
      let(:params) do
        {
          source_path: project_dir,
          output_path: 'output',
          target_automation: 'selenium',
          target_framework: 'cucumber'
        }
      end

      before do
        File.write("#{project_dir}/Gemfile", "gem 'cucumber'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/features/step_definitions")

        File.write("#{project_dir}/features/login.feature", <<~GHERKIN)
          Feature: Login
          Scenario: Valid login
            Given I am on the login page
        GHERKIN

        File.write("#{project_dir}/features/step_definitions/login_steps.rb", <<~RUBY)
          Given('I am on the login page') do
            @page = LoginPage.new(driver)
          end
        RUBY
      end

      it 'plans feature file copies' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.converted_features.length).to eq(1)
        expect(plan.converted_features.first.output_path).to eq('output/features/login.feature')
      end

      it 'plans step definition conversions' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.converted_steps.length).to eq(1)
        expect(plan.converted_steps.first.output_path).to eq('output/features/step_definitions/login_steps.rb')
      end

      it 'skips rspec-style test conversion for cucumber target' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.converted_tests).to be_empty
      end
    end

    context 'converting capybara to selenium' do
      let(:params) do
        {
          source_path: project_dir,
          output_path: 'output',
          target_automation: 'selenium',
          target_framework: 'rspec'
        }
      end

      before do
        File.write("#{project_dir}/Gemfile", "gem 'capybara'\ngem 'rspec'\n")
        FileUtils.mkdir_p("#{project_dir}/pages")

        File.write("#{project_dir}/pages/login_page.rb", <<~RUBY)
          class LoginPage < BasePage
            include Capybara::DSL
            def login(email, password)
              fill_in 'email', with: email
              click_button 'Login'
            end
          end
        RUBY
      end

      it 'adds a warning when no converter is registered' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.warnings).to include(match(/No converter for capybara.*selenium/))
      end

      it 'still includes the page with identity conversion' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.converted_pages.length).to eq(1)
      end
    end

    context 'with config overrides' do
      let(:params) do
        {
          source_path: project_dir,
          output_path: 'output',
          target_automation: 'selenium',
          target_framework: 'rspec',
          browser: 'firefox',
          url: 'https://override.com'
        }
      end

      before do
        File.write("#{project_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/config")
        File.write("#{project_dir}/config/config.yml", "browser: chrome\nurl: 'https://original.com'\n")
      end

      it 'uses parameter overrides over detected values' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        expect(plan.config_overrides[:browser]).to eq('firefox')
        expect(plan.config_overrides[:url]).to eq('https://override.com')
      end
    end

    context 'converting to capybara updates page instantiation' do
      let(:params) do
        {
          source_path: project_dir,
          output_path: 'output',
          target_automation: 'capybara',
          target_framework: 'cucumber'
        }
      end

      before do
        File.write("#{project_dir}/Gemfile", "gem 'cucumber'\ngem 'selenium-webdriver'\n")
        FileUtils.mkdir_p("#{project_dir}/features/step_definitions")

        File.write("#{project_dir}/features/login.feature", <<~GHERKIN)
          Feature: Login
          Scenario: Test
            Given I am on the login page
        GHERKIN

        File.write("#{project_dir}/features/step_definitions/login_steps.rb", <<~RUBY)
          Given('I am on the login page') do
            @page = LoginPage.new(driver)
          end
        RUBY
      end

      it 'removes driver argument from page instantiation in steps' do
        analysis = Adopter::ProjectAnalyzer.new(project_dir).analyze
        plan = described_class.new(analysis, params).build

        step_content = plan.converted_steps.first.content
        expect(step_content).to include('LoginPage.new')
        expect(step_content).not_to include('LoginPage.new(driver)')
      end
    end
  end
end
