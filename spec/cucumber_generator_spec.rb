# frozen_string_literal: true

require_relative '../lib/generators/cucumber_generator'
require_relative 'spec_helper'

describe RubyRaider::CucumberGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'cucumber-selenium'
      RubyRaider::CucumberGenerator.new(['selenium', 'cucumber', @name]).invoke_all
    end

    it 'creates a feature file' do
      expect(File.exist?("#{@name}/features/login.feature")).to be_truthy
    end

    it 'creates a step definitions file' do
      expect(File.exist?("#{@name}/features/step_definitions/login_steps.rb")).to be_truthy
    end

    it 'creates an env file' do
      expect(File.exist?("#{@name}/features/support/env.rb")).to be_truthy
    end

    it 'does not create a spec file' do
      expect(File.exist?("#{@name}/spec/login_spec.rb")).to be_falsey
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'cucumber-watir'
      RubyRaider::CucumberGenerator.new(['watir', 'cucumber', @name]).invoke_all
    end

    it 'creates a feature file' do
      expect(File.exist?("#{@name}/features/login.feature")).to be_truthy
    end

    it 'creates a step definitions file' do
      expect(File.exist?("#{@name}/features/step_definitions/login_steps.rb")).to be_truthy
    end

    it 'creates an env file' do
      expect(File.exist?("#{@name}/features/support/env.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'cucumber-appium'
      RubyRaider::CucumberGenerator.new(['appium_ios', 'cucumber', @name]).invoke_all
    end

    it 'creates a feature file' do
      expect(File.exist?("#{@name}/features/login.feature")).to be_truthy
    end

    it 'creates a step definitions file' do
      expect(File.exist?("#{@name}/features/step_definitions/login_steps.rb")).to be_truthy
    end

    it 'creates an env file' do
      expect(File.exist?("#{@name}/features/support/env.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end
end
