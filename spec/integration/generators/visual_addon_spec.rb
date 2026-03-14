# frozen_string_literal: true

require 'fileutils'
require_relative '../../../lib/generators/invoke_generators'
require_relative '../settings_helper'

describe 'Visual addon generation' do
  include InvokeGenerators
  include SettingsHelper

  # rubocop:disable RSpec/BeforeAfterAll, RSpec/InstanceVariable
  before(:all) do
    @visual_projects = []
    %w[rspec cucumber].each do |framework|
      %w[selenium watir].each do |automation|
        name = "visual_#{framework}_#{automation}"
        @visual_projects << { name:, framework:, automation: }
        InvokeGenerators.generate_framework(
          automation:, framework:, name:, visual: true
        )
      end
    end
  end

  after(:all) do
    @visual_projects.each { |p| FileUtils.rm_rf(p[:name]) }
  end
  # rubocop:enable RSpec/BeforeAfterAll, RSpec/InstanceVariable

  context 'with rspec and selenium' do
    let(:name) { 'visual_rspec_selenium' }

    it 'creates visual_helper.rb' do
      expect(File).to exist("#{name}/helpers/visual_helper.rb")
    end

    it 'creates visual_spec.rb' do
      expect(File).to exist("#{name}/spec/visual_spec.rb")
    end

    it 'includes chunky_png in Gemfile' do
      gemfile = File.read("#{name}/Gemfile")
      expect(gemfile).to include("gem 'chunky_png'")
    end

    it 'visual helper has valid Ruby syntax' do
      content = File.read("#{name}/helpers/visual_helper.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end

    it 'visual spec has valid Ruby syntax' do
      content = File.read("#{name}/spec/visual_spec.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end
  end

  context 'with cucumber and selenium' do
    let(:name) { 'visual_cucumber_selenium' }

    it 'creates visual_helper.rb' do
      expect(File).to exist("#{name}/helpers/visual_helper.rb")
    end

    it 'creates visual.feature' do
      expect(File).to exist("#{name}/features/visual.feature")
    end

    it 'creates visual_steps.rb' do
      expect(File).to exist("#{name}/features/step_definitions/visual_steps.rb")
    end

    it 'includes chunky_png in Gemfile' do
      gemfile = File.read("#{name}/Gemfile")
      expect(gemfile).to include("gem 'chunky_png'")
    end
  end

  context 'with rspec and watir' do
    let(:name) { 'visual_rspec_watir' }

    it 'creates visual_helper.rb' do
      expect(File).to exist("#{name}/helpers/visual_helper.rb")
    end

    it 'creates visual_spec.rb' do
      expect(File).to exist("#{name}/spec/visual_spec.rb")
    end
  end

  context 'without visual flag' do
    let(:name) { 'no_visual_rspec_selenium' }

    # rubocop:disable RSpec/BeforeAfterAll
    before(:all) do
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'no_visual_rspec_selenium'
      )
    end

    after(:all) do
      FileUtils.rm_rf('no_visual_rspec_selenium')
    end
    # rubocop:enable RSpec/BeforeAfterAll

    it 'does not create visual_helper.rb' do
      expect(File).not_to exist("#{name}/helpers/visual_helper.rb")
    end

    it 'does not include chunky_png in Gemfile' do
      gemfile = File.read("#{name}/Gemfile")
      expect(gemfile).not_to include("gem 'chunky_png'")
    end
  end
end
