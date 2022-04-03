require_relative '../lib/generators/files/common_file_generator'
require_relative 'spec_helper'

describe RubyRaider::CommonFileGenerator do
  before(:all) do
    @name = 'Cucumber-watir-1'
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@name, automation: 'watir')
  end

  it 'creates a config file' do
    expect(File.exist?("#{@name}/config/config.yml")).to be_truthy
  end

  it 'creates a rake file' do
    expect(File.exist?("#{@name}/Rakefile")).to be_truthy
  end

  it 'creates a readMe file' do
    expect(File.exist?("#{@name}/Readme.md")).to be_truthy
  end

  after(:all) do
    FileUtils.rm_rf(@name)
  end
end


