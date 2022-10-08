# frozen_string_literal: true

require_relative '../lib/generators/cucumber_generator'
require_relative 'spec_helper'

describe CucumberGenerator do
  frameworks = @frameworks
  automation_types = @automation_types

  context 'with selenium' do
    name = "#{frameworks.first}_#{automation_types[2]}"

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
      expect(File).not_to exist("#{name}/spec/login_spec.rb")
    end
  end

  context 'with watir' do
    name = "#{frameworks.first}_#{automation_types.last}"

    it 'creates a feature file' do
      expect(File).to exist("#{name}/features/login.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{name}/features/step_definitions/login_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{name}/features/support/env.rb")
    end
  end

  context 'with android appium' do
    name = "#{frameworks.first}_#{automation_types.first}"

    it 'creates a feature file' do
      expect(File).to exist("#{name}/features/home.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{name}/features/step_definitions/home_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{name}/features/support/env.rb")
    end
  end

  context 'with ios appium' do
    name = "#{frameworks.first}_#{automation_types[1]}"

    it 'creates a feature file' do
      expect(File).to exist("#{name}/features/home.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{name}/features/step_definitions/home_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{name}/features/support/env.rb")
    end
  end
end
