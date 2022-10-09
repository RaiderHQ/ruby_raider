# frozen_string_literal: true

require_relative '../lib/generators/cucumber_generator'
require_relative 'spec_helper'

describe CucumberGenerator do
  frameworks = @frameworks
  automation_types = @automation_types

  shared_examples 'creates cucumber files' do |name|
    it 'creates a feature file' do
      expect(File).to exist("#{name}/features/login.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{name}/features/step_definitions/login_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{name}/features/support/env.rb")
    end

    it 'does not create a spec file' do
      expect(File).not_to exist("#{name}/spec/home_spec.rb")
    end
  end

  context 'with cucumber and appium android' do
    include_examples 'creates cucumber files', "#{frameworks.first}_#{automation_types.first}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates cucumber files', "#{frameworks.first}_#{automation_types[1]}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates cucumber files', "#{frameworks.first}_#{automation_types[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates cucumber files', "#{frameworks.first}_#{automation_types.last}"
  end
end
