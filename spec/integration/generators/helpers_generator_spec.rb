# frozen_string_literal: true

require_relative '../../../lib/generators/helper_generator'
require_relative '../spec_helper'

describe HelpersGenerator do
  shared_examples 'creates common helpers' do |name|
    it 'creates an allure helper file' do
      expect(File).to exist("#{name}/helpers/allure_helper.rb")
    end
  end

  shared_examples 'creates selenium helpers' do |name|
    it 'creates a driver helper file' do
      expect(File).to exist("#{name}/helpers/driver_helper.rb")
    end
  end

  shared_examples 'creates watir helpers' do |name|
    it 'creates a browser helper file' do
      expect(File).to exist("#{name}/helpers/browser_helper.rb")
    end
  end

  shared_examples 'creates rspec helpers' do |name|
    it 'creates a spec helper file' do
      expect(File).to exist("#{name}/helpers/spec_helper.rb")
    end
  end

  shared_examples 'creates cucumber helpers' do |name|
    it 'does not create a spec helper' do
      expect(File).not_to exist("#{name}/helpers/spec_helper.rb")
    end
  end

  shared_examples 'creates cross platform helpers' do |name|
    it 'creates an appium helper file' do
      expect(File).to exist("#{name}/helpers/appium_helper.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'creates watir helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates common helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates cucumber helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates common helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'creates watir helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'creates cucumber helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates common helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
    include_examples 'creates cucumber helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates common helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
    include_examples 'creates cucumber helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates cross platform helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates common helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates cucumber helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates cross platform helpers', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
  end

end
