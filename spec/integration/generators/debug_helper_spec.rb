# frozen_string_literal: true

require_relative '../../../lib/generators/helper_generator'
require_relative '../spec_helper'

describe 'Debug helper generation' do
  shared_examples 'creates debug helper' do |name|
    it 'creates a debug_helper.rb file' do
      expect(File).to exist("#{name}/helpers/debug_helper.rb")
    end
  end

  shared_examples 'does not create debug helper' do |name|
    it 'does not create a debug_helper.rb file' do
      expect(File).not_to exist("#{name}/helpers/debug_helper.rb")
    end
  end

  # Web frameworks should get debug_helper
  context 'with rspec and selenium' do
    include_examples 'creates debug helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and watir' do
    include_examples 'creates debug helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates debug helper', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates debug helper', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end

  # Mobile frameworks should NOT get debug_helper
  context 'with rspec and appium android' do
    include_examples 'does not create debug helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'does not create debug helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'does not create debug helper', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
  end
end
