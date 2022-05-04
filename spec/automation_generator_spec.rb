# frozen_string_literal: true

require_relative '../lib/generators/files/tion_file_generator'
require_relative 'spec_helper'

describe RubyRaider::AutomationFileGenerator do
  context 'On a web project' do
    before(:all) do
      @name = 'Rspec-watir-1'
      RubyRaider::RspecProjectGenerator.generate_rspec_project('watir', @name)
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

    it 'creates a gemfile file' do
      expect(File.exist?("#{@name}/Gemfile")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    context 'On a mobile project' do
      before(:all) do
        @name = 'Rspec-appium-ios'
        RubyRaider::RspecProjectGenerator.generate_rspec_project('appium_ios', @name)
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/page_objects/pages/home_page.rb")).to be_truthy
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/page_objects/pages/confirmation_page.rb")).to be_truthy
      end

      it 'creates a login page file' do
        expect(File.exist?("#{@name}/appium.txt")).to be_truthy
      end

      after(:all) do
        FileUtils.rm_rf(@name)
      end
    end
  end
end
