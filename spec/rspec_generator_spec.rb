# frozen_string_literal: true

require_relative '../lib/generators/rspec_generator'
require_relative 'spec_helper'

describe RspecGenerator do
  context 'with selenium' do
    before(:all) do
      @name = 'rspec-selenium'
      described_class.new(['selenium', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a spec file' do
      expect(File).to exist("#{@name}/spec/login_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{@name}/spec/base_spec.rb")
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

    it 'creates a spec file' do
      expect(File).to exist("#{@name}/spec/login_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{@name}/spec/base_spec.rb")
    end
  end

  context 'with ios appium' do
    before(:all) do
      @name = 'rspec-appium'
      described_class.new(['ios', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a spec file' do
      expect(File).to exist("#{@name}/spec/pdp_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{@name}/spec/base_spec.rb")
    end
  end

  context 'with android appium' do
    before(:all) do
      @name = 'rspec-appium'
      described_class.new(['android', 'rspec', @name]).invoke_all
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end

    it 'creates a spec file' do
      expect(File).to exist("#{@name}/spec/pdp_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{@name}/spec/base_spec.rb")
    end
  end
end
