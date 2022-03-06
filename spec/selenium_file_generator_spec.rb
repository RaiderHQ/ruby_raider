require_relative '../lib/generators/files/selenium_file_generator'
require_relative 'spec_helper'

describe RubyRaider::SeleniumFileGenerator do
  it 'creates a login page file' do
    expect(File.exist?("#{@project_name}/page_objects/pages/login_page.rb")).to be_truthy
  end

  it 'creates an abstract page file' do
    expect(File.exist?("#{@project_name}/page_objects/abstract/abstract_page.rb")).to be_truthy
  end

  it 'creates an abstract page object file' do
    expect(File.exist?("#{@project_name}/page_objects/abstract/abstract_page_object.rb")).to be_truthy
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

