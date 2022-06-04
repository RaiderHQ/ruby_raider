# frozen_string_literal: true

require_relative '../lib/generators/automation_generator'
require_relative 'spec_helper'

describe AutomationGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      AutomationGenerator.new(['selenium', 'rspec', @name]).invoke_all
    end

    it 'creates a login page file' do
      expect(File.exist?("#{@name}/page_objects/pages/login_page.rb")).to be_truthy
    end

    it 'creates an abstract page file' do
      expect(File.exist?("#{@name}/page_objects/abstract/abstract_page.rb")).to be_truthy
    end

    it 'creates an abstract component file' do
      expect(File.exist?("#{@name}/page_objects/abstract/abstract_component.rb")).to be_truthy
    end

    it 'creates a component file' do
      expect(File.exist?("#{@name}/page_objects/components/header_component.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'rspec-watir'
      AutomationGenerator.new(['watir', 'rspec', @name]).invoke_all
    end

    it 'creates a login page file' do
      expect(File.exist?("#{@name}/page_objects/pages/login_page.rb")).to be_truthy
    end

    it 'creates an abstract page file' do
      expect(File.exist?("#{@name}/page_objects/abstract/abstract_page.rb")).to be_truthy
    end

    it 'creates an abstract component file' do
      expect(File.exist?("#{@name}/page_objects/abstract/abstract_component.rb")).to be_truthy
    end

    it 'creates a component file' do
      expect(File.exist?("#{@name}/page_objects/components/header_component.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'rspec-appium'
      AutomationGenerator.new(['appium_ios', 'rspec', @name]).invoke_all
    end

    it 'creates a login page file' do
      expect(File.exist?("#{@name}/page_objects/pages/login_page.rb")).to be_truthy
    end

    it 'creates an abstract page file' do
      expect(File.exist?("#{@name}/page_objects/abstract/abstract_page.rb")).to be_truthy
    end

    it "doesn't creates an abstract component file" do
      expect(File.exist?("#{@name}/page_objects/abstract/abstract_component.rb")).to be_falsey
    end

    it "doesn't creates a component file" do
      expect(File.exist?("#{@name}/page_objects/components/header_component.rb")).to be_falsey
    end

    it 'creates a login page file' do
      expect(File.exist?("#{@name}/page_objects/pages/home_page.rb")).to be_truthy
    end

    it 'creates a confirmation page file' do
      expect(File.exist?("#{@name}/page_objects/pages/confirmation_page.rb")).to be_truthy
    end

    it 'creates an appium config file' do
      expect(File.exist?("#{@name}/appium.txt")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    context 'with cucumber and selenium' do
      before(:all) do
        @name = 'cucumber-selenium'
        AutomationGenerator.new(['selenium', 'cucumber', @name]).invoke_all
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/page_objects/pages/login_page.rb")).to be_truthy
      end

      it 'creates an abstract page file' do
        expect(File.exist?("#{@name}/page_objects/abstract/abstract_page.rb")).to be_truthy
      end

      it 'creates an abstract component file' do
        expect(File.exist?("#{@name}/page_objects/abstract/abstract_component.rb")).to be_truthy
      end

      it 'creates a component file' do
        expect(File.exist?("#{@name}/page_objects/components/header_component.rb")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end

    context 'with cucumber and watir' do
      before(:all) do
        @name = 'cucumber-watir'
        AutomationGenerator.new(['watir', 'cucumber', @name]).invoke_all
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/page_objects/pages/login_page.rb")).to be_truthy
      end

      it 'creates an abstract page file' do
        expect(File.exist?("#{@name}/page_objects/abstract/abstract_page.rb")).to be_truthy
      end

      it 'creates an abstract component file' do
        expect(File.exist?("#{@name}/page_objects/abstract/abstract_component.rb")).to be_truthy
      end

      it 'creates a component file' do
        expect(File.exist?("#{@name}/page_objects/components/header_component.rb")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end

    context 'with cucumber and appium' do
      before(:all) do
        @name = 'cucumber-appium'
        AutomationGenerator.new(['appium_ios', 'cucumber', @name]).invoke_all
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/page_objects/pages/login_page.rb")).to be_truthy
      end

      it 'creates an abstract page file' do
        expect(File.exist?("#{@name}/page_objects/abstract/abstract_page.rb")).to be_truthy
      end

      it "doesn't creates an abstract component file" do
        expect(File.exist?("#{@name}/page_objects/abstract/abstract_component.rb")).to be_falsey
      end

      it "doesn't creates a component file" do
        expect(File.exist?("#{@name}/page_objects/components/header_component.rb")).to be_falsey
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/page_objects/pages/home_page.rb")).to be_truthy
      end

      it 'creates a confirmation page file' do
        expect(File.exist?("#{@name}/page_objects/pages/confirmation_page.rb")).to be_truthy
      end

      it 'creates an appium config file' do
        expect(File.exist?("#{@name}/appium.txt")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end
  end
end
