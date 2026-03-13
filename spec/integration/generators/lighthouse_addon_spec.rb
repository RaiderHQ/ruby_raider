# frozen_string_literal: true

require 'fileutils'
require_relative '../../../lib/generators/invoke_generators'
require_relative '../settings_helper'

describe 'Lighthouse addon generation' do
  include InvokeGenerators
  include SettingsHelper

  # rubocop:disable RSpec/BeforeAfterAll, RSpec/InstanceVariable
  before(:all) do
    @lighthouse_projects = []
    %w[rspec cucumber minitest].each do |framework|
      %w[selenium watir capybara].each do |automation|
        name = "lighthouse_#{framework}_#{automation}"
        @lighthouse_projects << { name:, framework:, automation: }
        InvokeGenerators.generate_framework(
          automation:, framework:, name:, performance: true
        )
      end
    end
  end

  after(:all) do
    @lighthouse_projects.each { |p| FileUtils.rm_rf(p[:name]) }
  end
  # rubocop:enable RSpec/BeforeAfterAll, RSpec/InstanceVariable

  context 'with rspec and selenium' do
    let(:name) { 'lighthouse_rspec_selenium' }

    it 'creates performance_helper.rb' do
      expect(File).to exist("#{name}/helpers/performance_helper.rb")
    end

    it 'creates performance_spec.rb' do
      expect(File).to exist("#{name}/spec/performance_spec.rb")
    end

    it 'performance helper has valid Ruby syntax' do
      content = File.read("#{name}/helpers/performance_helper.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end

    it 'performance spec has valid Ruby syntax' do
      content = File.read("#{name}/spec/performance_spec.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end
  end

  context 'with cucumber and selenium' do
    let(:name) { 'lighthouse_cucumber_selenium' }

    it 'creates performance_helper.rb' do
      expect(File).to exist("#{name}/helpers/performance_helper.rb")
    end

    it 'creates performance.feature' do
      expect(File).to exist("#{name}/features/performance.feature")
    end

    it 'creates performance_steps.rb' do
      expect(File).to exist("#{name}/features/step_definitions/performance_steps.rb")
    end
  end

  context 'with minitest and selenium' do
    let(:name) { 'lighthouse_minitest_selenium' }

    it 'creates performance_helper.rb' do
      expect(File).to exist("#{name}/helpers/performance_helper.rb")
    end

    it 'creates test_performance.rb' do
      expect(File).to exist("#{name}/test/test_performance.rb")
    end

    it 'performance test has valid Ruby syntax' do
      content = File.read("#{name}/test/test_performance.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end
  end

  context 'with rspec and watir' do
    let(:name) { 'lighthouse_rspec_watir' }

    it 'creates performance_helper.rb' do
      expect(File).to exist("#{name}/helpers/performance_helper.rb")
    end

    it 'creates performance_spec.rb' do
      expect(File).to exist("#{name}/spec/performance_spec.rb")
    end
  end

  context 'with rspec and capybara' do
    let(:name) { 'lighthouse_rspec_capybara' }

    it 'creates performance_helper.rb' do
      expect(File).to exist("#{name}/helpers/performance_helper.rb")
    end

    it 'creates performance_spec.rb' do
      expect(File).to exist("#{name}/spec/performance_spec.rb")
    end
  end

  context 'without performance flag' do
    let(:name) { 'no_lighthouse_rspec_selenium' }

    # rubocop:disable RSpec/BeforeAfterAll
    before(:all) do
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'no_lighthouse_rspec_selenium'
      )
    end

    after(:all) do
      FileUtils.rm_rf('no_lighthouse_rspec_selenium')
    end
    # rubocop:enable RSpec/BeforeAfterAll

    it 'does not create performance_helper.rb' do
      expect(File).not_to exist("#{name}/helpers/performance_helper.rb")
    end

    it 'does not create performance_spec.rb' do
      expect(File).not_to exist("#{name}/spec/performance_spec.rb")
    end
  end
end
