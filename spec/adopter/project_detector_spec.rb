# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/adopter/project_detector'

RSpec.describe Adopter::ProjectDetector do
  let(:project_dir) { 'tmp_test_project' }

  before { FileUtils.mkdir_p(project_dir) }

  after { FileUtils.rm_rf(project_dir) }

  describe '.detect' do
    it 'returns a hash with detection results' do
      expect(described_class.detect(project_dir)).to be_a(Hash)
    end

    it 'excludes nil values from the result' do
      expect(described_class.detect(project_dir).values).not_to include(nil)
    end
  end

  describe '.detect_framework' do
    subject(:framework) { described_class.detect_framework(project_dir) }

    context 'when Gemfile contains rspec' do
      before { File.write("#{project_dir}/Gemfile", "gem 'rspec'\n") }

      it { is_expected.to eq('rspec') }
    end

    context 'when Gemfile contains cucumber' do
      before { File.write("#{project_dir}/Gemfile", "gem 'cucumber'\n") }

      it { is_expected.to eq('cucumber') }
    end

    context 'when Gemfile contains minitest' do
      before { File.write("#{project_dir}/Gemfile", "gem 'minitest'\n") }

      it { is_expected.to eq('minitest') }
    end

    context 'when no Gemfile but spec/ exists' do
      before { FileUtils.mkdir_p("#{project_dir}/spec") }

      it { is_expected.to eq('rspec') }
    end

    context 'when no Gemfile but features/ exists' do
      before { FileUtils.mkdir_p("#{project_dir}/features") }

      it { is_expected.to eq('cucumber') }
    end

    context 'when no Gemfile but test/ exists' do
      before { FileUtils.mkdir_p("#{project_dir}/test") }

      it { is_expected.to eq('minitest') }
    end

    context 'when nothing is present' do
      it { is_expected.to be_nil }
    end
  end

  describe '.detect_automation' do
    subject(:automation) { described_class.detect_automation(project_dir) }

    %w[selenium-webdriver watir appium_lib].zip(%w[selenium watir appium]).each do |gem_name, expected|
      context "with #{gem_name} in Gemfile" do
        before { File.write("#{project_dir}/Gemfile", "gem '#{gem_name}'\n") }

        it { is_expected.to eq(expected) }
      end
    end

    { 'eyes_selenium' => 'applitools', 'axe-core-selenium' => 'axe',
      'capybara' => 'capybara', 'site_prism' => 'capybara' }.each do |gem_name, expected|
      context "with #{gem_name} in Gemfile" do
        before { File.write("#{project_dir}/Gemfile", "gem '#{gem_name}'\n") }

        it { is_expected.to eq(expected) }
      end
    end

    context 'with capybara and selenium-webdriver in Gemfile' do
      before { File.write("#{project_dir}/Gemfile", "gem 'capybara'\ngem 'selenium-webdriver'\n") }

      it 'prioritizes capybara over selenium' do
        expect(automation).to eq('capybara')
      end
    end

    context 'with no Gemfile but require in source files' do
      before do
        FileUtils.mkdir_p("#{project_dir}/spec")
        File.write("#{project_dir}/spec/test.rb", "require 'selenium-webdriver'\n")
      end

      it { is_expected.to eq('selenium') }
    end

    context 'with no Gemfile but capybara require in source files' do
      before do
        FileUtils.mkdir_p("#{project_dir}/spec")
        File.write("#{project_dir}/spec/test.rb", "require 'capybara'\n")
      end

      it { is_expected.to eq('capybara') }
    end

    context 'with no Gemfile but site_prism require in source files' do
      before do
        FileUtils.mkdir_p("#{project_dir}/spec")
        File.write("#{project_dir}/spec/test.rb", "require 'site_prism'\n")
      end

      it { is_expected.to eq('capybara') }
    end
  end

  describe '.detect_page_path' do
    subject(:page_path) { described_class.detect_page_path(project_dir) }

    { 'page_objects/pages' => 'page_objects/pages', 'pages' => 'pages', 'page' => 'page' }.each do |dir, expected|
      context "with #{dir} directory" do
        before { FileUtils.mkdir_p("#{project_dir}/#{dir}") }

        it { is_expected.to eq(expected) }
      end
    end
  end

  describe '.detect_spec_path' do
    subject(:spec_path) { described_class.detect_spec_path(project_dir) }

    { 'spec' => 'spec', 'test' => 'test', 'tests' => 'tests' }.each do |dir, expected|
      context "with #{dir} directory" do
        before { FileUtils.mkdir_p("#{project_dir}/#{dir}") }

        it { is_expected.to eq(expected) }
      end
    end
  end

  describe '.detect_feature_path' do
    context 'with features directory' do
      before { FileUtils.mkdir_p("#{project_dir}/features") }

      it 'detects features path' do
        expect(described_class.detect_feature_path(project_dir)).to eq('features')
      end
    end
  end

  describe '.detect_helper_path' do
    subject(:helper_path) { described_class.detect_helper_path(project_dir) }

    { 'helpers' => 'helpers', 'support' => 'support', 'features/support' => 'features/support' }.each do |dir, expected|
      context "with #{dir} directory" do
        before { FileUtils.mkdir_p("#{project_dir}/#{dir}") }

        it { is_expected.to eq(expected) }
      end
    end
  end

  describe '.detect_browser' do
    subject(:browser) { described_class.detect_browser(project_dir) }

    context 'with browser in spec_helper' do
      before do
        FileUtils.mkdir_p("#{project_dir}/spec")
        File.write("#{project_dir}/spec/spec_helper.rb", "browser = :firefox\n")
      end

      it { is_expected.to eq('firefox') }
    end

    context 'with browser in config.yml' do
      before do
        FileUtils.mkdir_p("#{project_dir}/config")
        File.write("#{project_dir}/config/config.yml", "browser: chrome\n")
      end

      it { is_expected.to eq('chrome') }
    end
  end

  describe '.detect_url' do
    subject(:url) { described_class.detect_url(project_dir) }

    context 'with base_url in spec_helper' do
      before do
        FileUtils.mkdir_p("#{project_dir}/spec")
        File.write("#{project_dir}/spec/spec_helper.rb", "base_url = 'https://example.com'\n")
      end

      it { is_expected.to eq('https://example.com') }
    end

    context 'with app_host in env.rb' do
      before do
        FileUtils.mkdir_p("#{project_dir}/features/support")
        File.write("#{project_dir}/features/support/env.rb", "app_host = 'https://staging.example.com'\n")
      end

      it { is_expected.to eq('https://staging.example.com') }
    end
  end

  describe '.detect_ci_platform' do
    subject(:ci_platform) { described_class.detect_ci_platform(project_dir) }

    context 'with .github/workflows directory' do
      before { FileUtils.mkdir_p("#{project_dir}/.github/workflows") }

      it { is_expected.to eq('github') }
    end

    context 'with .gitlab-ci.yml file' do
      before { File.write("#{project_dir}/.gitlab-ci.yml", "stages:\n  - test\n") }

      it { is_expected.to eq('gitlab') }
    end

    context 'with no CI configuration' do
      it { is_expected.to be_nil }
    end
  end

  describe 'full project detection' do
    before do
      File.write("#{project_dir}/Gemfile", <<~GEMFILE)
        source 'https://rubygems.org'
        gem 'rspec'
        gem 'selenium-webdriver'
        gem 'rake'
      GEMFILE
      FileUtils.mkdir_p("#{project_dir}/spec")
      FileUtils.mkdir_p("#{project_dir}/page_objects/pages")
      FileUtils.mkdir_p("#{project_dir}/helpers")
      FileUtils.mkdir_p("#{project_dir}/.github/workflows")
      FileUtils.mkdir_p("#{project_dir}/config")
      File.write("#{project_dir}/config/config.yml", "browser: chrome\nurl: 'https://example.com'\n")
    end

    it 'detects all components of a complete project' do
      expect(described_class.detect(project_dir)).to include(
        automation: 'selenium',
        framework: 'rspec',
        page_path: 'page_objects/pages',
        spec_path: 'spec',
        helper_path: 'helpers',
        browser: 'chrome',
        url: 'https://example.com',
        ci_platform: 'github'
      )
    end
  end

  describe 'full capybara + minitest project detection' do
    before do
      File.write("#{project_dir}/Gemfile", <<~GEMFILE)
        source 'https://rubygems.org'
        gem 'minitest'
        gem 'capybara'
        gem 'selenium-webdriver'
        gem 'site_prism'
        gem 'rake'
      GEMFILE
      FileUtils.mkdir_p("#{project_dir}/test")
      FileUtils.mkdir_p("#{project_dir}/pages")
      FileUtils.mkdir_p("#{project_dir}/support")
      File.write("#{project_dir}/.gitlab-ci.yml", "stages:\n  - test\n")
      FileUtils.mkdir_p("#{project_dir}/config")
      File.write("#{project_dir}/config/config.yml", "browser: firefox\nurl: 'https://staging.example.com'\n")
    end

    it 'detects capybara + minitest project' do
      expect(described_class.detect(project_dir)).to include(
        automation: 'capybara',
        framework: 'minitest',
        page_path: 'pages',
        spec_path: 'test',
        helper_path: 'support',
        browser: 'firefox',
        url: 'https://staging.example.com',
        ci_platform: 'gitlab'
      )
    end
  end
end
