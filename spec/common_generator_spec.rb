# frozen_string_literal: true

require_relative '../lib/generators/common_generator'
require_relative 'spec_helper'

describe CommonGenerator do
  shared_examples 'creates common files' do |name|
    it 'creates a rake file' do
      expect(File).to exist("#{name}/Rakefile")
    end

    it 'creates a readMe file' do
      expect(File).to exist("#{name}/Readme.md")
    end

    it 'creates a gemfile file' do
      expect(File).to exist("#{name}/Gemfile")
    end
  end

  shared_examples 'creates a config file' do |name|
    it 'creates a config file' do
      expect(File).to exist("#{name}/config/config.yml")
    end
  end

  shared_examples "doesn't create a config file" do |name|
    it "doesn't create a config file" do
      expect(File).not_to exist("#{name}/config/config.yml")
    end
  end

  shared_examples 'creates an options file' do |name|
    it 'creates an options file' do
      expect(File).to exist("#{name}/config/options.yml")
    end
  end

  shared_examples 'creates a capabilities file' do |name|
    it 'creates a capabilities file' do
      expect(File).to exist("#{name}/config/capabilities.yml")
    end
  end

  shared_examples 'creates a gitignore file' do |name|
    it 'creates a gitignore file' do
      expect(File).to exist("#{name}/.gitignore")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates a config file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates a config file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with rspec, selenium and applitools' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_visual"
    include_examples 'creates a config file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_visual"
    include_examples 'creates an options file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_visual"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_visual"
  end

  context 'with rspec, watir and applitools' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_visual"
    include_examples 'creates a config file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_visual"
    include_examples 'creates an options file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_visual"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_visual"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates a config file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates a config file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates a capabilities file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
    include_examples "doesn't create a config file", "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates a capabilities file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
    include_examples "doesn't create a config file", "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates a capabilities file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
    include_examples "doesn't create a config file", "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates a capabilities file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
    include_examples "doesn't create a config file", "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates a capabilities file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates a config file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates a capabilities file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates a config file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates a gitignore file', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
  end
end
