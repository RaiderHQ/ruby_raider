# frozen_string_literal: true

require_relative '../lib/generators/helper_generator'
require_relative 'spec_helper'

describe RubyRaider::HelpersGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      RubyRaider::HelpersGenerator.new(['selenium', 'rspec', @name]).invoke_all
    end

    it 'creates a raider file' do
      expect(File.exist?("#{@name}/helpers/raider.rb")).to be_truthy
    end

    it 'creates a pom helper file' do
      expect(File.exist?("#{@name}/helpers/pom_helper.rb")).to be_truthy
    end

    it 'creates an allure helper file' do
      expect(File.exist?("#{@name}/helpers/allure_helper.rb")).to be_truthy
    end

    it 'creates a driver helper file', :watir do
      expect(File.exist?("#{@name}/helpers/driver_helper.rb")).to be_truthy
    end

    it 'creates a spec helper file' do
      expect(File.exist?("#{@name}/helpers/spec_helper.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'rspec-watir'
      RubyRaider::HelpersGenerator.new(['watir', 'rspec', @name]).invoke_all
    end

    it 'creates a browser helper file', :watir do
      expect(File.exist?("#{@name}/helpers/browser_helper.rb")).to be_truthy
    end

    it 'creates a pom helper file' do
      expect(File.exist?("#{@name}/helpers/pom_helper.rb")).to be_truthy
    end

    it 'creates a raider file' do
      expect(File.exist?("#{@name}/helpers/raider.rb")).to be_truthy
    end

    it 'creates an allure helper file' do
      expect(File.exist?("#{@name}/helpers/allure_helper.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'rspec-appium'
      RubyRaider::HelpersGenerator.new(['appium_ios', 'rspec', @name]).invoke_all
    end

    it 'creates a raider file' do
      expect(File.exist?("#{@name}/helpers/raider.rb")).to be_truthy
    end

    it 'creates a pom helper file' do
      expect(File.exist?("#{@name}/helpers/pom_helper.rb")).to be_truthy
    end

    it 'creates an allure helper file' do
      expect(File.exist?("#{@name}/helpers/allure_helper.rb")).to be_truthy
    end

    it 'creates a driver helper file', :watir do
      expect(File.exist?("#{@name}/helpers/driver_helper.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    context 'with cucumber and selenium' do
      before(:all) do
        @name = 'cucumber-selenium'
        RubyRaider::HelpersGenerator.new(['selenium', 'cucumber', @name]).invoke_all
      end

      it 'creates a pom helper file' do
        expect(File.exist?("#{@name}/helpers/pom_helper.rb")).to be_truthy
      end

      it 'creates an allure helper file' do
        expect(File.exist?("#{@name}/helpers/allure_helper.rb")).to be_truthy
      end

      it 'creates a driver helper file', :watir do
        expect(File.exist?("#{@name}/helpers/driver_helper.rb")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end

    context 'with cucumber and watir' do
      before(:all) do
        @name = 'cucumber-watir'
        RubyRaider::HelpersGenerator.new(['watir', 'cucumber', @name]).invoke_all
      end

      it 'creates a browser helper file', :watir do
        expect(File.exist?("#{@name}/helpers/browser_helper.rb")).to be_truthy
      end

      it 'creates a raider file' do
        expect(File.exist?("#{@name}/helpers/raider.rb")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end
  end
end