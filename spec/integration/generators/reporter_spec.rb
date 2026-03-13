# frozen_string_literal: true

require 'fileutils'
require_relative '../../../lib/generators/invoke_generators'

describe 'Reporter selection for project generation' do
  include InvokeGenerators

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    %w[reporter_allure_test reporter_junit_test reporter_both_test reporter_none_test].each do |name|
      FileUtils.rm_rf(name)
    end
  end

  describe 'reporter: allure' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'reporter_allure_test', reporter: 'allure'
      )
    end

    it 'generates allure_helper.rb' do
      expect(File).to exist('reporter_allure_test/helpers/allure_helper.rb')
    end

    it 'creates allure-results directory' do
      expect(File).to exist('reporter_allure_test/allure-results')
    end

    it 'includes allure gems in Gemfile' do
      gemfile = File.read('reporter_allure_test/Gemfile')
      expect(gemfile).to include('allure-rspec')
    end

    it 'does not include junit gem in Gemfile' do
      gemfile = File.read('reporter_allure_test/Gemfile')
      expect(gemfile).not_to include('rspec_junit_formatter')
    end

    it 'references AllureHelper in spec_helper' do
      helper = File.read('reporter_allure_test/helpers/spec_helper.rb')
      expect(helper).to include('AllureHelper')
    end
  end

  describe 'reporter: junit' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'reporter_junit_test', reporter: 'junit'
      )
    end

    it 'does not generate allure_helper.rb' do
      expect(File).not_to exist('reporter_junit_test/helpers/allure_helper.rb')
    end

    it 'does not create allure-results directory' do
      expect(File).not_to exist('reporter_junit_test/allure-results')
    end

    it 'does not include allure gems in Gemfile' do
      gemfile = File.read('reporter_junit_test/Gemfile')
      expect(gemfile).not_to include('allure-rspec')
    end

    it 'includes junit gem in Gemfile' do
      gemfile = File.read('reporter_junit_test/Gemfile')
      expect(gemfile).to include('rspec_junit_formatter')
    end

    it 'includes junit formatter in spec_helper' do
      helper = File.read('reporter_junit_test/helpers/spec_helper.rb')
      expect(helper).to include('RspecJunitFormatter')
    end

    it 'does not reference AllureHelper in spec_helper' do
      helper = File.read('reporter_junit_test/helpers/spec_helper.rb')
      expect(helper).not_to include('AllureHelper')
    end

    it 'generates spec_helper.rb with valid syntax' do
      helper = File.read('reporter_junit_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe 'reporter: both' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'reporter_both_test', reporter: 'both'
      )
    end

    it 'generates allure_helper.rb' do
      expect(File).to exist('reporter_both_test/helpers/allure_helper.rb')
    end

    it 'includes allure gems in Gemfile' do
      gemfile = File.read('reporter_both_test/Gemfile')
      expect(gemfile).to include('allure-rspec')
    end

    it 'includes junit gem in Gemfile' do
      gemfile = File.read('reporter_both_test/Gemfile')
      expect(gemfile).to include('rspec_junit_formatter')
    end

    it 'references AllureHelper in spec_helper' do
      helper = File.read('reporter_both_test/helpers/spec_helper.rb')
      expect(helper).to include('AllureHelper')
    end

    it 'includes junit formatter in spec_helper' do
      helper = File.read('reporter_both_test/helpers/spec_helper.rb')
      expect(helper).to include('RspecJunitFormatter')
    end

    it 'generates spec_helper.rb with valid syntax' do
      helper = File.read('reporter_both_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe 'reporter: none' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'reporter_none_test', reporter: 'none'
      )
    end

    it 'does not generate allure_helper.rb' do
      expect(File).not_to exist('reporter_none_test/helpers/allure_helper.rb')
    end

    it 'does not create allure-results directory' do
      expect(File).not_to exist('reporter_none_test/allure-results')
    end

    it 'does not include allure gems in Gemfile' do
      gemfile = File.read('reporter_none_test/Gemfile')
      expect(gemfile).not_to include('allure-rspec')
    end

    it 'does not include junit gem in Gemfile' do
      gemfile = File.read('reporter_none_test/Gemfile')
      expect(gemfile).not_to include('rspec_junit_formatter')
    end

    it 'does not reference AllureHelper in spec_helper' do
      helper = File.read('reporter_none_test/helpers/spec_helper.rb')
      expect(helper).not_to include('AllureHelper')
    end

    it 'generates spec_helper.rb with valid syntax' do
      helper = File.read('reporter_none_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end
end
