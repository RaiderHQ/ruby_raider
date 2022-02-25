require_relative '../lib/generators/files/watir_file_generator'
require_relative 'spec_helper'

describe RubyRaider::WatirFileGenerator do
  it 'creates a login page file' do
    expect(File.exist?("#{@project_name}/page_objects/pages/login_page.rb")).to be_truthy
  end

  it 'creates an abstract page file' do
    expect(File.exist?("#{@project_name}/page_objects/abstract/abstract_page.rb")).to be_truthy
  end

  it 'creates a gemfile file' do
    expect(File.exist?("#{@project_name}/Gemfile")).to be_truthy
  end
end

