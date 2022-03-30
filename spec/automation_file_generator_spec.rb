require_relative '../lib/generators/files/automation_file_generator'
require_relative 'spec_helper'

describe RubyRaider::AutomationFileGenerator do
  it 'creates a login page file', :rspec_watir do
    expect(File.exist?("#{@project_name}/page_objects/pages/login_page.rb")).to be_truthy
  end

  it 'creates an abstract page file' do
    expect(File.exist?("#{@project_name}/page_objects/abstract/abstract_page.rb")).to be_truthy
  end

  it 'creates an abstract component file' do
    expect(File.exist?("#{@project_name}/page_objects/abstract/abstract_component.rb")).to be_truthy
  end

  it 'creates a component file' do
    expect(File.exist?("#{@project_name}/page_objects/components/header_component.rb")).to be_truthy
  end

  it 'creates a gemfile file' do
    expect(File.exist?("#{@project_name}/Gemfile")).to be_truthy
  end
end

