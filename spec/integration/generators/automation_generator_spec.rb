# frozen_string_literal: true

require_relative '../../../lib/generators/automation/automation_generator'
require_relative '../spec_helper'

describe AutomationGenerator do
  shared_examples 'creates web automation framework' do |name|
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header.rb")
    end
  end

  shared_examples 'creates mobile automation framework' do |name|
    it 'creates a home page file' do
      expect(File).to exist("#{name}/page_objects/pages/home.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{name}/page_objects/pages/pdp.rb")
    end
  end

  shared_examples 'creates web visual framework' do |name|
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/page.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates web visual framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::APPLITOOLS}"
  end

  context 'with rspec and watir' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates web visual framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::APPLITOOLS}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
  end
end
