require_relative '../lib/generators/files/helpers_file_generator'
require_relative 'spec_helper'

describe RubyRaider::HelpersFileGenerator do
  context 'When the users selects rspec' do
    before(:all) do
      @name = 'Rspec-watir-2'
      RubyRaider::RspecProjectGenerator.generate_rspec_project('selenium', @name)
    end

    it 'creates a raider file' do
      expect(File.exist?("#{@name}/helpers/raider.rb")).to be_truthy
    end

    it 'creates an allure helper file' do
      expect(File.exist?("#{@name}/helpers/allure_helper.rb")).to be_truthy
    end

    it 'creates a driver helper file', :watir do
      expect(File.exist?("#{@name}/helpers/driver_helper.rb")).to be_truthy
    end

    it 'creates a pom helper file' do
      expect(File.exist?("#{@name}/helpers/pom_helper.rb")).to be_truthy
    end

    it 'creates a spec helper file' do
      expect(File.exist?("#{@name}/helpers/spec_helper.rb")).to be_truthy
    end

    it 'creates a watir helper file' do
      expect(File.exist?("#{@name}/helpers/allure_helper.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end

  context 'when the user selects cucumber' do
    before(:all) do
      @name = 'Cucumber-watir-3'
      RubyRaider::CucumberProjectGenerator.generate_cucumber_project('watir', @name)
    end

    it 'creates a raider file' do
      expect(File.exist?("#{@name}/features/support/helpers/raider.rb")).to be_truthy
    end

    it 'creates an allure helper file' do
      expect(File.exist?("#{@name}/features/support/helpers/allure_helper.rb")).to be_truthy
    end

    it 'creates a browser helper file', :watir do
      expect(File.exist?("#{@name}/features/support/helpers/browser_helper.rb")).to be_truthy
    end

    it 'creates a pom helper file' do
      expect(File.exist?("#{@name}/features/support/helpers/pom_helper.rb")).to be_truthy
    end

    it 'creates a watir helper file' do
      expect(File.exist?("#{@name}/features/support/helpers/allure_helper.rb")).to be_truthy
    end

    after(:all) do
      FileUtils.rm_rf(@name)
    end
  end
end



