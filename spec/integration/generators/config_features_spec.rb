# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative '../../../lib/generators/invoke_generators'

describe 'Config features for generated projects' do
  include InvokeGenerators

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    %w[config_selenium_test config_capybara_test config_watir_test
       reporter_json_rspec_test reporter_json_cucumber_test reporter_json_minitest_test].each do |name|
      FileUtils.rm_rf(name)
    end
  end

  describe 'timeout and viewport in config.yml' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'config_selenium_test', reporter: 'none'
      )
    end

    it 'includes timeout key with default value of 10' do
      config = YAML.load_file('config_selenium_test/config/config.yml')
      expect(config['timeout']).to eq 10
    end

    it 'includes viewport with width and height' do
      config = YAML.load_file('config_selenium_test/config/config.yml')
      expect(config['viewport']).to eq({ 'width' => 1920, 'height' => 1080 })
    end

    it 'does not include hardcoded driver_options timeouts' do
      config = YAML.load_file('config_selenium_test/config/config.yml')
      expect(config['driver_options']).to be_nil
    end

    it 'generates driver_helper with timeout from config' do
      helper = File.read('config_selenium_test/helpers/driver_helper.rb')
      expect(helper).to include("config.fetch('timeout', 10)")
    end

    it 'generates spec_helper with viewport-aware window setup' do
      helper = File.read('config_selenium_test/helpers/spec_helper.rb')
      expect(helper).to include('viewport')
      expect(helper).to include('resize_to')
    end

    it 'generates spec_helper with valid Ruby syntax' do
      helper = File.read('config_selenium_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe 'timeout in Capybara helper' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'capybara', framework: 'rspec', name: 'config_capybara_test', reporter: 'none'
      )
    end

    it 'reads timeout from config in capybara_helper' do
      helper = File.read('config_capybara_test/helpers/capybara_helper.rb')
      expect(helper).to include("config.fetch('timeout', 10)")
    end

    it 'generates spec_helper with viewport-aware window setup' do
      helper = File.read('config_capybara_test/helpers/spec_helper.rb')
      expect(helper).to include('viewport')
    end

    it 'generates spec_helper with valid Ruby syntax' do
      helper = File.read('config_capybara_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe 'timeout in Watir helper' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'watir', framework: 'rspec', name: 'config_watir_test', reporter: 'none'
      )
    end

    it 'sets Watir.default_timeout from config' do
      helper = File.read('config_watir_test/helpers/browser_helper.rb')
      expect(helper).to include("Watir.default_timeout = config.fetch('timeout', 10)")
    end

    it 'generates spec_helper with viewport-aware window setup' do
      helper = File.read('config_watir_test/helpers/spec_helper.rb')
      expect(helper).to include('viewport')
    end

    it 'generates spec_helper with valid Ruby syntax' do
      helper = File.read('config_watir_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe 'reporter: json with RSpec' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'reporter_json_rspec_test', reporter: 'json'
      )
    end

    it 'includes json formatter in spec_helper' do
      helper = File.read('reporter_json_rspec_test/helpers/spec_helper.rb')
      expect(helper).to include("config.add_formatter('json', 'results/results.json')")
    end

    it 'does not include allure in spec_helper' do
      helper = File.read('reporter_json_rspec_test/helpers/spec_helper.rb')
      expect(helper).not_to include('AllureHelper')
    end

    it 'generates spec_helper with valid Ruby syntax' do
      helper = File.read('reporter_json_rspec_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe 'reporter: json with Cucumber' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'cucumber', name: 'reporter_json_cucumber_test', reporter: 'json'
      )
    end

    it 'includes json profile in cucumber.yml' do
      cucumber_yml = File.read('reporter_json_cucumber_test/cucumber.yml')
      expect(cucumber_yml).to include('--format json --out results/results.json')
    end
  end

  describe 'reporter: json with Minitest' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'minitest', name: 'reporter_json_minitest_test', reporter: 'json'
      )
    end

    it 'includes JsonReporter in test_helper' do
      helper = File.read('reporter_json_minitest_test/helpers/test_helper.rb')
      expect(helper).to include('Minitest::Reporters::JsonReporter')
    end

    it 'generates test_helper with valid Ruby syntax' do
      helper = File.read('reporter_json_minitest_test/helpers/test_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end
end
