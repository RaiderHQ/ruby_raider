# frozen_string_literal: true

require_relative '../../../lib/generators/cucumber/cucumber_generator'
require_relative '../spec_helper'

describe CucumberGenerator do
  shared_examples 'creates cucumber files' do |project_name, file_name|
    it 'creates a feature file' do
      expect(File).to exist("#{project_name}/features/#{file_name}.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{project_name}/features/step_definitions/#{file_name}_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{project_name}/features/support/env.rb")
    end

    it 'creates an cucumber.yml file' do
      expect(File).to exist("#{project_name}/cucumber.yml")
    end

    it 'does not create a spec file' do
      expect(File).not_to exist("#{project_name}/spec/home_spec.rb")
    end
  end

  shared_examples 'creates factories for web projects' do |project_name|
    it 'creates an data file' do
      expect(File).to exist("#{project_name}/models/data/users.yml")
    end

    it 'creates a model factory' do
      expect(File).to exist("#{project_name}/models/model_factory.rb")
    end

    it 'creates a user factory' do
      expect(File).to exist("#{project_name}/models/user_factory.rb")
    end
  end

  context 'with cucumber and appium android' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}", 'home'
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}", 'home'
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[4]}", 'home'
  end

  context 'with cucumber and selenium' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}", 'login'
    include_examples 'creates factories for web projects', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}", 'login'
  end

  context 'with cucumber and watir' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}", 'login'
    include_examples 'creates factories for web projects', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}", 'login'
  end
end
