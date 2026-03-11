# frozen_string_literal: true

require_relative '../../../lib/generators/common_generator'
require_relative '../spec_helper'

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
    include_examples 'creates common files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates a config file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'creates a config file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with rspec, selenium and applitools' do
    include_examples 'creates common files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::APPLITOOLS}"
    include_examples 'creates a config file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::APPLITOOLS}"
    include_examples 'creates an options file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::APPLITOOLS}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::APPLITOOLS}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates common files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates a config file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates common files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'creates a config file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates a capabilities file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples "doesn't create a config file", "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates a capabilities file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples "doesn't create a config file", "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates common files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
    include_examples 'creates a capabilities file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
    include_examples "doesn't create a config file", "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates common files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
    include_examples 'creates a capabilities file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
    include_examples "doesn't create a config file", "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates common files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates a capabilities file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates a config file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates common files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates a capabilities file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates a config file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates a gitignore file', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
  end
end
