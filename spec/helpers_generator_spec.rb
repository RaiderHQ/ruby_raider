# frozen_string_literal: true

require_relative '../lib/generators/helper_generator'
require_relative 'spec_helper'

describe HelpersGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      described_class.new(['selenium', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a raider file' do
      expect(File).to exist("#{@name}/helpers/raider.rb")
    end

    it 'creates an allure helper file' do
      expect(File).to exist("#{@name}/helpers/allure_helper.rb")
    end

    it 'creates a driver helper file', :watir do
      expect(File).to exist("#{@name}/helpers/driver_helper.rb")
    end

    it 'creates a spec helper file' do
      expect(File).to exist("#{@name}/helpers/spec_helper.rb")
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'rspec-watir'
      described_class.new(['watir', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a browser helper file', :watir do
      expect(File).to exist("#{@name}/helpers/browser_helper.rb")
    end

    it 'creates a raider file' do
      expect(File).to exist("#{@name}/helpers/raider.rb")
    end

    it 'creates an allure helper file' do
      expect(File).to exist("#{@name}/helpers/allure_helper.rb")
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'rspec-appium'
      described_class.new(['appium_ios', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a raider file' do
      expect(File).to exist("#{@name}/helpers/raider.rb")
    end

    it 'creates an allure helper file' do
      expect(File).to exist("#{@name}/helpers/allure_helper.rb")
    end

    it 'creates a driver helper file', :watir do
      expect(File).to exist("#{@name}/helpers/driver_helper.rb")
    end

    context 'with cucumber and selenium' do
      before(:all) do
        @name = 'cucumber-selenium'
        described_class.new(['selenium', 'cucumber', @name]).invoke_all
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end

      it 'creates an allure helper file' do
        expect(File).to exist("#{@name}/helpers/allure_helper.rb")
      end

      it 'creates a driver helper file', :watir do
        expect(File).to exist("#{@name}/helpers/driver_helper.rb")
      end

      it 'does not create a spec helper' do
        expect(File).not_to exist("#{@name}/helpers/spec_helper.rb")
      end
    end

    context 'with cucumber and watir' do
      before(:all) do
        @name = 'cucumber-watir'
        described_class.new(['watir', 'cucumber', @name]).invoke_all
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end

      it 'creates a browser helper file', :watir do
        expect(File).to exist("#{@name}/helpers/browser_helper.rb")
      end

      it 'creates a raider file' do
        expect(File).to exist("#{@name}/helpers/raider.rb")
      end

      it 'does not create a spec helper' do
        expect(File).not_to exist("#{@name}/helpers/spec_helper.rb")
      end
    end
  end
end
