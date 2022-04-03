require_relative '../lib/generators/files/automation_file_generator'
require_relative 'spec_helper'

describe RubyRaider::AutomationFileGenerator do
  before(:all) do
    @name = 'Rspec-watir-1'
    RubyRaider::RspecProjectGenerator.generate_rspec_project(@name, automation: 'watir')
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
end

