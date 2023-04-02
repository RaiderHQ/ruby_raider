# frozen_string_literal: true

require_relative '../lib/generators/cucumber/cucumber_generator'
require_relative 'spec_helper'

describe CucumberGenerator do
  shared_examples 'creates cucumber files without examples' do |project_name, file_name|
    it 'creates a feature file' do
      expect(File).not_to exist("#{project_name}/features/#{file_name}.feature")
    end

    it 'creates a step definitions file' do
      expect(File).not_to exist("#{project_name}/features/step_definitions/#{file_name}_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{project_name}/features/support/env.rb")
    end

    it 'does not create a spec file' do
      expect(File).not_to exist("#{project_name}/spec/home_spec.rb")
    end
  end

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

    it 'does not create a spec file' do
      expect(File).not_to exist("#{project_name}/spec/home_spec.rb")
    end
  end

  context 'with cucumber and appium android' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}", 'home'
    include_examples 'creates cucumber files without examples',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}_without_examples", 'home'
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}", 'home'
    include_examples 'creates cucumber files without examples',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}_without_examples", 'home'
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}", 'home'
    include_examples 'creates cucumber files without examples',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}_without_examples", 'home'
  end

  context 'with cucumber and selenium' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}", 'login'
    include_examples 'creates cucumber files without examples',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}_without_examples", 'login'
  end

  context 'with cucumber and watir' do
    include_examples 'creates cucumber files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}", 'login'
    include_examples 'creates cucumber files without examples',
                     "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}_without_examples", 'login'
  end
end
