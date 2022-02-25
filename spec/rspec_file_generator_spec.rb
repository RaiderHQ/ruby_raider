require_relative '../lib/generators/files/rspec_file_generator'
require_relative 'spec_helper'

describe RubyRaider::RspecFileGenerator do
  it 'creates a spec file' do
    expect(File.exist?("#{@project_name}/spec/login_page_spec.rb")).to be_truthy
  end

  it 'creates the base spec file' do
    expect(File.exist?("#{@project_name}/spec/base_spec.rb")).to be_truthy
  end
end
