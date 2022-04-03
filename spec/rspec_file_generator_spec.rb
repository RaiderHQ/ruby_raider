require_relative '../lib/generators/files/rspec_file_generator'
require_relative 'spec_helper'

describe RubyRaider::RspecFileGenerator do
  before(:all) do
    @name = 'Rspec-watir-3'
    RubyRaider::RspecProjectGenerator.generate_rspec_project(@name, automation: 'watir')
  end

  it 'creates a spec file' do
    expect(File.exist?("#{@name}/spec/login_page_spec.rb")).to be_truthy
  end

  it 'creates the base spec file' do
    expect(File.exist?("#{@name}/spec/base_spec.rb")).to be_truthy
  end

  after(:all) do
    FileUtils.rm_rf(@name)
  end
end
