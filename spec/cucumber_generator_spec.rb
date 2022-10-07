# frozen_string_literal: true

require_relative '../lib/generators/cucumber_generator'
require_relative 'spec_helper'

describe CucumberGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'cucumber-selenium'
      described_class.new(['selenium', 'cucumber', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a feature file' do
      expect(File).to exist("#{@name}/features/login.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{@name}/features/step_definitions/login_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{@name}/features/support/env.rb")
    end

    it 'does not create a spec file' do
      expect(File).not_to exist("#{@name}/spec/login_spec.rb")
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'cucumber-watir'
      described_class.new(['watir', 'cucumber', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a feature file' do
      expect(File).to exist("#{@name}/features/login.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{@name}/features/step_definitions/login_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{@name}/features/support/env.rb")
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'cucumber-appium'
      described_class.new(['appium_ios', 'cucumber', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a feature file' do
      expect(File).to exist("#{@name}/features/login.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{@name}/features/step_definitions/login_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{@name}/features/support/env.rb")
    end
  end
end
