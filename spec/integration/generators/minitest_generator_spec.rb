# frozen_string_literal: true

require_relative '../../../lib/generators/minitest/minitest_generator'
require_relative '../spec_helper'

describe MinitestGenerator do
  shared_examples 'creates factory files' do |project_name|
    it 'creates a model factory file' do
      expect(File).to exist("#{project_name}/models/model_factory.rb")
    end

    it 'creates the data for the factory' do
      expect(File).to exist("#{project_name}/models/data/users.yml")
    end
  end

  shared_examples 'creates minitest files examples' do |project_name, file_name|
    it 'creates a test file' do
      expect(File).to exist("#{project_name}/test/test_#{file_name}_page.rb")
    end
  end

  shared_examples 'creates test helper' do |project_name|
    it 'creates a test helper file' do
      expect(File).to exist("#{project_name}/helpers/test_helper.rb")
    end
  end

  context 'with minitest and selenium' do
    include_examples 'creates factory files', "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates minitest files examples',
                     "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}", 'login'
    include_examples 'creates test helper', "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}"
  end

  context 'with minitest and watir' do
    include_examples 'creates factory files', "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}"
    include_examples 'creates minitest files examples',
                     "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}", 'login'
    include_examples 'creates test helper', "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}"
  end

  context 'with minitest and capybara' do
    include_examples 'creates factory files', "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}"
    include_examples 'creates minitest files examples',
                     "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}", 'login'
    include_examples 'creates test helper', "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}"
  end

  context 'with minitest and appium android' do
    include_examples 'creates minitest files examples',
                     "#{FrameworkIndex::MINITEST}_#{AutomationIndex::ANDROID}", 'pdp'
  end

  context 'with minitest and appium ios' do
    include_examples 'creates minitest files examples',
                     "#{FrameworkIndex::MINITEST}_#{AutomationIndex::IOS}", 'pdp'
  end

  context 'with minitest and appium cross platform' do
    include_examples 'creates minitest files examples',
                     "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CROSS_PLATFORM}", 'pdp'
  end
end
