# frozen_string_literal: true

require_relative '../../../lib/generators/rspec/rspec_generator'
require_relative '../../spec_helper'

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
    include_examples 'creates factory files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates rspec files examples',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}", 'login'
  end

  context 'with rspec and watir' do
    include_examples 'creates factory files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
    include_examples 'creates rspec files examples',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}", 'login'
  end

  context 'with rspec and appium android' do
    include_examples 'creates rspec files examples',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}", 'pdp'
  end

  context 'with rspec and appium ios' do
    include_examples 'creates rspec files examples',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}", 'pdp'
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates rspec files examples',
                     "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}", 'pdp'
  end
end
