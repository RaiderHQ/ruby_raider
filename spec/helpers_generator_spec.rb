# frozen_string_literal: true

require_relative '../lib/generators/helper_generator'
require_relative 'spec_helper'

describe HelpersGenerator do
  shared_examples 'creates common helpers' do |name|
    it 'creates a raider file' do
      expect(File).to exist("#{name}/helpers/raider.rb")
    end

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
    it 'creates a browser helper file' do
      expect(File).to exist("#{name}/helpers/appium_helper.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates rspec helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates watir helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates rspec helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates cucumber helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates watir helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
    include_examples 'creates cucumber helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates rspec helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates rspec helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
    include_examples 'creates cucumber helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
    include_examples 'creates cucumber helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates rspec helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates cross platform helpers', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates common helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates selenium helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates cucumber helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
    include_examples 'creates cross platform helpers', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
  end
end
