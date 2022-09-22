# frozen_string_literal: true

require_relative '../lib/generators/rspec_generator'
require_relative 'spec_helper'

describe RspecGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      RspecGenerator.new(['selenium', 'rspec', @name]).invoke_all
    end

    it 'creates a spec file' do
      expect(File.exist?("#{@name}/spec/pdp_page_spec.rb")).to be_truthy
    end

    it 'creates the base spec file' do
      expect(File.exist?("#{@name}/spec/base_spec.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with watir' do
    before(:all) do
      @name = 'rspec-watir'
      RspecGenerator.new(['watir', 'rspec', @name]).invoke_all
    end

    it 'creates a spec file' do
      expect(File.exist?("#{@name}/spec/pdp_page_spec.rb")).to be_truthy
    end

    it 'creates the base spec file' do
      expect(File.exist?("#{@name}/spec/base_spec.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'with appium' do
    before(:all) do
      @name = 'rspec-appium'
      RspecGenerator.new(['appium_ios', 'rspec', @name]).invoke_all
    end

    it 'creates a spec file' do
      expect(File.exist?("#{@name}/spec/pdp_page_spec.rb")).to be_truthy
    end

    it 'creates the base spec file' do
      expect(File.exist?("#{@name}/spec/base_spec.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end
end
