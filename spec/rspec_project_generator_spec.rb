# frozen_string_literal: true

require_relative 'spec_helper'

describe RubyRaider::RspecProjectGenerator do
  context 'On a web project' do
    before(:all) do
      @name = 'Rspec'
      RubyRaider::RspecProjectGenerator.generate_rspec_project('selenium', @name)
    end

    it 'creates a project folder' do
      expect(Dir.exist?(@name)).to be_truthy
    end

    it 'creates a spec folder' do
      expect(Dir.exist?("#{@name}/spec")).to be_truthy
    end

    it 'creates a page objects folder' do
      expect(Dir.exist?("#{@name}/page_objects")).to be_truthy
    end

    it 'creates an abstract page object folder' do
      expect(Dir.exist?("#{@name}/page_objects/abstract")).to be_truthy
    end

    it 'creates a pages folder' do
      expect(Dir.exist?("#{@name}/page_objects/pages")).to be_truthy
    end

    it 'creates a components folder' do
      expect(Dir.exist?("#{@name}/page_objects/components")).to be_truthy
    end

    it 'creates a helper folder' do
      expect(Dir.exist?("#{@name}/helpers")).to be_truthy
    end

    it 'creates a data folder' do
      expect(Dir.exist?("#{@name}/data")).to be_truthy
    end

    it 'creates a config folder' do
      expect(Dir.exist?("#{@name}/config")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'On a mobile project' do
    before(:all) do
      @name = 'appium-ios-1'
      RubyRaider::RspecProjectGenerator.generate_rspec_project('appium_ios', @name)
    end

    it "doesn't creates a config folder" do
      expect(Dir.exist?("#{@name}/config")).to be_falsey
    end

    it "doesn't creates a components folder" do
      expect(Dir.exist?("#{@name}/page_objects/components")).to be_falsey
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end
end
