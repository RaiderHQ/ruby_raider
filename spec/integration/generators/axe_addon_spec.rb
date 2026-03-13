# frozen_string_literal: true

require 'fileutils'
require_relative '../../../lib/generators/invoke_generators'
require_relative '../settings_helper'

describe 'Axe accessibility addon generation' do
  include InvokeGenerators
  include SettingsHelper

  # rubocop:disable RSpec/BeforeAfterAll, RSpec/InstanceVariable
  before(:all) do
    @axe_projects = []
    %w[rspec cucumber minitest].each do |framework|
      %w[selenium watir capybara].each do |automation|
        name = "axe_#{framework}_#{automation}"
        @axe_projects << name
        InvokeGenerators.generate_framework(
          automation:, framework:, name:, accessibility: true
        )
      end
    end
  end

  after(:all) do
    @axe_projects.each { |name| FileUtils.rm_rf(name) }
  end
  # rubocop:enable RSpec/BeforeAfterAll, RSpec/InstanceVariable

  context 'with rspec and selenium' do
    let(:name) { 'axe_rspec_selenium' }

    it 'creates accessibility_spec.rb' do
      expect(File).to exist("#{name}/spec/accessibility_spec.rb")
    end

    it 'includes axe gems in Gemfile' do
      gemfile = File.read("#{name}/Gemfile")
      expect(gemfile).to include('axe')
    end

    it 'accessibility spec has valid Ruby syntax' do
      content = File.read("#{name}/spec/accessibility_spec.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end
  end

  context 'with cucumber and selenium' do
    let(:name) { 'axe_cucumber_selenium' }

    it 'creates accessibility.feature' do
      expect(File).to exist("#{name}/features/accessibility.feature")
    end

    it 'creates accessibility_steps.rb' do
      expect(File).to exist("#{name}/features/step_definitions/accessibility_steps.rb")
    end

    it 'includes axe gems in Gemfile' do
      gemfile = File.read("#{name}/Gemfile")
      expect(gemfile).to include('axe')
    end
  end

  context 'with minitest and selenium' do
    let(:name) { 'axe_minitest_selenium' }

    it 'creates test_accessibility.rb' do
      expect(File).to exist("#{name}/test/test_accessibility.rb")
    end

    it 'includes axe gems in Gemfile' do
      gemfile = File.read("#{name}/Gemfile")
      expect(gemfile).to include('axe')
    end

    it 'accessibility test has valid Ruby syntax' do
      content = File.read("#{name}/test/test_accessibility.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end
  end

  context 'with rspec and watir' do
    let(:name) { 'axe_rspec_watir' }

    it 'creates accessibility_spec.rb' do
      expect(File).to exist("#{name}/spec/accessibility_spec.rb")
    end
  end

  context 'with rspec and capybara' do
    let(:name) { 'axe_rspec_capybara' }

    it 'creates accessibility_spec.rb' do
      expect(File).to exist("#{name}/spec/accessibility_spec.rb")
    end
  end

  context 'with cucumber and watir' do
    let(:name) { 'axe_cucumber_watir' }

    it 'creates accessibility.feature' do
      expect(File).to exist("#{name}/features/accessibility.feature")
    end
  end

  context 'with cucumber and capybara' do
    let(:name) { 'axe_cucumber_capybara' }

    it 'creates accessibility.feature' do
      expect(File).to exist("#{name}/features/accessibility.feature")
    end
  end

  context 'with minitest and watir' do
    let(:name) { 'axe_minitest_watir' }

    it 'creates test_accessibility.rb' do
      expect(File).to exist("#{name}/test/test_accessibility.rb")
    end
  end

  context 'with minitest and capybara' do
    let(:name) { 'axe_minitest_capybara' }

    it 'creates test_accessibility.rb' do
      expect(File).to exist("#{name}/test/test_accessibility.rb")
    end
  end

  context 'without accessibility flag' do
    let(:name) { 'no_axe_rspec_selenium' }

    # rubocop:disable RSpec/BeforeAfterAll
    before(:all) do
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'no_axe_rspec_selenium'
      )
    end

    after(:all) do
      FileUtils.rm_rf('no_axe_rspec_selenium')
    end
    # rubocop:enable RSpec/BeforeAfterAll

    it 'does not create accessibility_spec.rb' do
      expect(File).not_to exist("#{name}/spec/accessibility_spec.rb")
    end
  end
end
