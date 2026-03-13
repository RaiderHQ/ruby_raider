# frozen_string_literal: true

require_relative 'content_helper'
require 'fileutils'

describe 'Reporter content validation' do
  include InvokeGenerators

  # Generate projects with different reporter configurations
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    %w[allure junit both none].each do |reporter|
      %w[rspec cucumber minitest].each do |framework|
        name = "reporter_#{reporter}_#{framework}"
        InvokeGenerators.generate_framework(
          automation: 'selenium', framework: framework, name: name, reporter: reporter
        )
      end
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    %w[allure junit both none].each do |reporter|
      %w[rspec cucumber minitest].each do |framework|
        FileUtils.rm_rf("reporter_#{reporter}_#{framework}")
      end
    end
  end

  # --- Shared examples ---

  shared_examples 'project with allure' do |project_name|
    it 'generates allure_helper.rb' do
      expect(File).to exist("#{project_name}/helpers/allure_helper.rb")
    end

    it 'creates allure-results directory' do
      expect(File).to exist("#{project_name}/allure-results")
    end

    it 'includes allure-results in .gitignore' do
      gitignore = read_generated(project_name, '.gitignore')
      expect(gitignore).to include('allure-results')
    end
  end

  shared_examples 'project without allure' do |project_name|
    it 'does not generate allure_helper.rb' do
      expect(File).not_to exist("#{project_name}/helpers/allure_helper.rb")
    end

    it 'does not create allure-results directory' do
      expect(File).not_to exist("#{project_name}/allure-results")
    end

    it 'does not include allure-results in .gitignore' do
      gitignore = read_generated(project_name, '.gitignore')
      expect(gitignore).not_to include('allure-results')
    end
  end

  shared_examples 'rspec with allure reporter' do |project_name|
    it 'includes allure gems in Gemfile' do
      gemfile = read_generated(project_name, 'Gemfile')
      expect(gemfile).to include("gem 'allure-rspec'")
      expect(gemfile).to include("gem 'allure-ruby-commons'")
    end

    it 'references AllureHelper in spec_helper' do
      helper = read_generated(project_name, 'helpers/spec_helper.rb')
      expect(helper).to include("require_relative 'allure_helper'")
      expect(helper).to include('AllureHelper.configure')
      expect(helper).to include('config.formatter = AllureHelper.formatter')
    end

    it 'allure_helper has valid Ruby syntax' do
      content = read_generated(project_name, 'helpers/allure_helper.rb')
      expect(content).to have_valid_ruby_syntax
    end
  end

  shared_examples 'rspec without allure reporter' do |project_name|
    it 'does not include allure gems in Gemfile' do
      gemfile = read_generated(project_name, 'Gemfile')
      expect(gemfile).not_to include("gem 'allure-rspec'")
    end

    it 'does not reference AllureHelper in spec_helper' do
      helper = read_generated(project_name, 'helpers/spec_helper.rb')
      expect(helper).not_to include('AllureHelper')
    end
  end

  shared_examples 'rspec with junit reporter' do |project_name|
    it 'includes rspec_junit_formatter gem in Gemfile' do
      gemfile = read_generated(project_name, 'Gemfile')
      expect(gemfile).to include("gem 'rspec_junit_formatter'")
    end

    it 'configures junit formatter in spec_helper' do
      helper = read_generated(project_name, 'helpers/spec_helper.rb')
      expect(helper).to include("config.add_formatter('RspecJunitFormatter', 'results/junit.xml')")
    end
  end

  shared_examples 'rspec without junit reporter' do |project_name|
    it 'does not include rspec_junit_formatter gem in Gemfile' do
      gemfile = read_generated(project_name, 'Gemfile')
      expect(gemfile).not_to include("gem 'rspec_junit_formatter'")
    end

    it 'does not configure junit formatter in spec_helper' do
      helper = read_generated(project_name, 'helpers/spec_helper.rb')
      expect(helper).not_to include('RspecJunitFormatter')
    end
  end

  shared_examples 'cucumber with allure reporter' do |project_name|
    it 'includes allure-cucumber gem in Gemfile' do
      gemfile = read_generated(project_name, 'Gemfile')
      expect(gemfile).to include("gem 'allure-cucumber'")
    end

    it 'configures allure formatter in cucumber.yml' do
      cucumber_yml = read_generated(project_name, 'cucumber.yml')
      expect(cucumber_yml).to include('AllureCucumber::CucumberFormatter')
      expect(cucumber_yml).to include('--out allure-results')
    end
  end

  shared_examples 'cucumber without allure reporter' do |project_name|
    it 'does not include allure-cucumber gem in Gemfile' do
      gemfile = read_generated(project_name, 'Gemfile')
      expect(gemfile).not_to include("gem 'allure-cucumber'")
    end

    it 'does not configure allure formatter in cucumber.yml' do
      cucumber_yml = read_generated(project_name, 'cucumber.yml')
      expect(cucumber_yml).not_to include('AllureCucumber')
    end
  end

  shared_examples 'valid ruby files' do |project_name|
    it 'generates spec_helper or test_helper with valid syntax' do
      %w[helpers/spec_helper.rb helpers/test_helper.rb].each do |path|
        file = File.join(project_name, path)
        next unless File.exist?(file)

        content = File.read(file)
        expect(content).to have_valid_ruby_syntax
        expect(content).to have_frozen_string_literal
      end
    end
  end

  # --- reporter: allure ---

  context 'with reporter: allure' do
    context 'and rspec' do
      name = 'reporter_allure_rspec'
      it_behaves_like 'project with allure', name
      it_behaves_like 'rspec with allure reporter', name
      it_behaves_like 'rspec without junit reporter', name
      it_behaves_like 'valid ruby files', name
    end

    context 'and cucumber' do
      name = 'reporter_allure_cucumber'
      it_behaves_like 'project with allure', name
      it_behaves_like 'cucumber with allure reporter', name
      it_behaves_like 'valid ruby files', name
    end
  end

  # --- reporter: junit ---

  context 'with reporter: junit' do
    context 'and rspec' do
      name = 'reporter_junit_rspec'
      it_behaves_like 'project without allure', name
      it_behaves_like 'rspec without allure reporter', name
      it_behaves_like 'rspec with junit reporter', name
      it_behaves_like 'valid ruby files', name
    end

    context 'and cucumber' do
      name = 'reporter_junit_cucumber'
      it_behaves_like 'project without allure', name
      it_behaves_like 'cucumber without allure reporter', name
      it_behaves_like 'valid ruby files', name
    end
  end

  # --- reporter: both ---

  context 'with reporter: both' do
    context 'and rspec' do
      name = 'reporter_both_rspec'
      it_behaves_like 'project with allure', name
      it_behaves_like 'rspec with allure reporter', name
      it_behaves_like 'rspec with junit reporter', name
      it_behaves_like 'valid ruby files', name
    end

    context 'and cucumber' do
      name = 'reporter_both_cucumber'
      it_behaves_like 'project with allure', name
      it_behaves_like 'cucumber with allure reporter', name
      it_behaves_like 'valid ruby files', name
    end
  end

  # --- reporter: none ---

  context 'with reporter: none' do
    context 'and rspec' do
      name = 'reporter_none_rspec'
      it_behaves_like 'project without allure', name
      it_behaves_like 'rspec without allure reporter', name
      it_behaves_like 'rspec without junit reporter', name
      it_behaves_like 'valid ruby files', name
    end

    context 'and cucumber' do
      name = 'reporter_none_cucumber'
      it_behaves_like 'project without allure', name
      it_behaves_like 'cucumber without allure reporter', name
      it_behaves_like 'valid ruby files', name
    end

    context 'and minitest' do
      name = 'reporter_none_minitest'
      it_behaves_like 'project without allure', name
      it_behaves_like 'valid ruby files', name
    end
  end
end
