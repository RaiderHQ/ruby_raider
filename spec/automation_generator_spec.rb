# frozen_string_literal: true

require_relative '../lib/generators/automation_generator'
require_relative 'spec_helper'

describe AutomationGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      described_class.new(['selenium', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a login page file' do
      expect(File).to exist("#{@name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{@name}/page_objects/components/header_component.rb")
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

    it 'creates a login page file' do
      expect(File).to exist("#{@name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{@name}/page_objects/components/header_component.rb")
    end
  end

  context 'with rspec and appium on ios' do
    before(:all) do
      @name = 'rspec-appium-ios'
      described_class.new(['ios', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a home page file' do
      expect(File).to exist("#{@name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{@name}/page_objects/pages/pdp_page.rb")
    end

    it 'creates an appium config file' do
      expect(File).to exist("#{@name}/appium.txt")
    end
  end

  context 'with rspec and appium on android' do
    before(:all) do
      @name = 'rspec-appium-android'
      described_class.new(['android', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a home page file' do
      expect(File).to exist("#{@name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{@name}/page_objects/pages/pdp_page.rb")
    end

    it 'creates an appium config file' do
      expect(File).to exist("#{@name}/appium.txt")
    end
  end

  context 'with cucumber and selenium' do
    before(:all) do
      @name = 'cucumber-selenium'
      described_class.new(['selenium', 'cucumber', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a login page file' do
      expect(File).to exist("#{@name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{@name}/page_objects/components/header_component.rb")
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

    it 'creates a login page file' do
      expect(File).to exist("#{@name}/page_objects/pages/login_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{@name}/page_objects/components/header_component.rb")
    end
  end

  context 'with cucumber and appium' do
    before(:all) do
      @name = 'cucumber-appium'
      described_class.new(['ios', 'cucumber', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a home page file' do
      expect(File).to exist("#{@name}/page_objects/pages/home_page.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{@name}/page_objects/abstract/abstract_page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{@name}/page_objects/pages/pdp_page.rb")
    end

    it 'creates an appium config file' do
      expect(File).to exist("#{@name}/appium.txt")
    end
  end
end
