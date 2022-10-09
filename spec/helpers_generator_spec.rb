# frozen_string_literal: true

require_relative '../lib/generators/helper_generator'
require_relative 'spec_helper'

describe HelpersGenerator do
  frameworks = @frameworks
  automation_types = @automation_types

  shared_examples 'creates common helpers' do |name|
    it 'creates a raider file' do
      expect(File).to exist("#{name}/helpers/raider.rb")
    end

    it 'creates an allure helper file' do
      expect(File).to exist("#{name}/helpers/allure_helper.rb")
    end
  end

  shared_examples 'selenium helpers' do |name|
    it 'creates a driver helper file' do
      expect(File).to exist("#{name}/helpers/driver_helper.rb")
    end
  end

  shared_examples 'watir helpers' do |name|
    it 'creates a browser helper file' do
      expect(File).to exist("#{name}/helpers/browser_helper.rb")
    end
  end

  shared_examples 'rspec helpers' do |name|
    it 'creates a spec helper file' do
      expect(File).to exist("#{name}/helpers/spec_helper.rb")
    end
  end

  shared_examples 'cucumber helpers' do |name|
    it 'does not create a spec helper' do
      expect(File).not_to exist("#{name}/helpers/spec_helper.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates common helpers', "#{frameworks.last}_#{automation_types[2]}"
    include_examples 'creates selenium helpers', "#{frameworks.last}_#{automation_types[2]}"
    include_examples 'creates rspec helpers', "#{frameworks.last}_#{automation_types[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common helpers', "#{frameworks.last}_#{automation_types.last}"
    include_examples 'creates watir helpers', "#{frameworks.last}_#{automation_types.last}"
    include_examples 'creates rspec helpers', "#{frameworks.last}_#{automation_types.last}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates common helpers', "#{frameworks.first}_#{automation_types[2]}"
    include_examples 'creates selenium helpers', "#{frameworks.first}_#{automation_types[2]}"
    include_examples 'creates cucumber helpers', "#{frameworks.first}_#{automation_types[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates common helpers', "#{frameworks.first}_#{automation_types.last}"
    include_examples 'creates watir helpers', "#{frameworks.first}_#{automation_types.last}"
    include_examples 'creates cucumber helpers', "#{frameworks.first}_#{automation_types.last}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common helpers', "#{frameworks.last}_#{automation_types.first}"
    include_examples 'creates selenium helpers', "#{frameworks.last}_#{automation_types.first}"
    include_examples 'creates rspec helpers', "#{frameworks.last}_#{automation_types.first}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common helpers', "#{frameworks.last}_#{automation_types[1]}"
    include_examples 'creates selenium helpers', "#{frameworks.last}_#{automation_types[1]}"
    include_examples 'creates rspec helpers', "#{frameworks.last}_#{automation_types[1]}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates common helpers', "#{frameworks.first}_#{automation_types.first}"
    include_examples 'creates selenium helpers', "#{frameworks.first}_#{automation_types.first}"
    include_examples 'creates cucumber helpers', "#{frameworks.first}_#{automation_types.first}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates common helpers', "#{frameworks.first}_#{automation_types[1]}"
    include_examples 'creates selenium helpers', "#{frameworks.first}_#{automation_types[1]}"
    include_examples 'creates cucumber helpers', "#{frameworks.first}_#{automation_types[1]}"
  end
end
