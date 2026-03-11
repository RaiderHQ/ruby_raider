# frozen_string_literal: true

require_relative '../../../lib/generators/rspec/rspec_generator'
require_relative '../spec_helper'

describe RspecGenerator do
  shared_examples 'creates factory files' do |project_name|
    it 'creates a model factory file' do
      expect(File).to exist("#{project_name}/models/model_factory.rb")
    end

    it 'creates the data for the factory' do
      expect(File).to exist("#{project_name}/models/data/users.yml")
    end
  end

  shared_examples 'creates rspec files examples' do |project_name, file_name|
    it 'creates a spec file' do
      expect(File).to exist("#{project_name}/spec/#{file_name}_page_spec.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates factory files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates rspec files examples',
                     "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}", 'login'
  end

  context 'with rspec and watir' do
    include_examples 'creates factory files', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates rspec files examples',
                     "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}", 'login'
  end

  context 'with rspec and appium android' do
    include_examples 'creates rspec files examples',
                     "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}", 'pdp'
  end

  context 'with rspec and appium ios' do
    include_examples 'creates rspec files examples',
                     "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}", 'pdp'
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates rspec files examples',
                     "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}", 'pdp'
  end
end
