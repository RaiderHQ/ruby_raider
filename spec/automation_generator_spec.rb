# frozen_string_literal: true

require_relative '../lib/generators/automation/automation_generator'
require_relative 'spec_helper'

describe AutomationGenerator do
  shared_examples 'creates web automation framework with example files' do |name|
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header_component.rb")
    end
  end

  shared_examples 'creates web automation framework without example files' do |name|
    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a login page file' do
      expect(File).not_to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates a component file' do
      expect(File).not_to exist("#{name}/page_objects/components/header_component.rb")
    end
  end

  shared_examples 'creates mobile automation framework with example files' do |name|
    it 'creates a home page file' do
      expect(File).to exist("#{name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{name}/page_objects/pages/pdp_page.rb")
    end
  end

  shared_examples 'creates mobile automation framework without example files' do |name|
    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a home page file' do
      expect(File).not_to exist("#{name}/page_objects/pages/home_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).not_to exist("#{name}/page_objects/pages/pdp_page.rb")
    end
  end

  shared_examples 'creates web visual framework with example files' do |name|
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end
  end

  shared_examples 'creates web visual framework without example files' do |name|
    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/abstract_page.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates web automation framework with example files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates web automation framework without example files',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_without_examples"
    include_examples 'creates web visual framework with example files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_visual"
  end

  context 'with rspec and watir' do
    include_examples 'creates web automation framework with example files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates web automation framework without example files',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_without_examples"
    include_examples 'creates web visual framework with example files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_visual"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates web automation framework with example files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates web automation framework without example files',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}_without_examples"
  end

  context 'with cucumber and watir' do
    include_examples 'creates web automation framework with example files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates web automation framework without example files',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}_without_examples"
  end

  context 'with rspec and appium android' do
    include_examples 'creates mobile automation framework with example files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates mobile automation framework without example files',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}_without_examples"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates mobile automation framework with example files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates mobile automation framework without example files',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}_without_examples"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates mobile automation framework with example files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates mobile automation framework without example files',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}_without_examples"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates mobile automation framework with example files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates mobile automation framework without example files',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}_without_examples"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates mobile automation framework with example files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates mobile automation framework without example files',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}_without_examples"
  end
end
