# frozen_string_literal: true

require_relative '../lib/generators/cucumber_generator'
require_relative 'spec_helper'

describe RubyRaider::CucumberGenerator do
  context 'with cucumber and selenium' do
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

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with cucumber and watir' do
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
  end
end
