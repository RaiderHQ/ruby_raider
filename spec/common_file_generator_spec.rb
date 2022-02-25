require_relative '../lib/generators/files/common_file_generator'
require_relative 'spec_helper'

describe RubyRaider::CommonFileGenerator do
  it 'creates a config file' do
    expect(File.exist?("#{@project_name}/config/config.yml")).to be_truthy
  end

  it 'creates a rake file' do
    expect(File.exist?("#{@project_name}/Rakefile")).to be_truthy
  end

  it 'creates a readMe file' do
    expect(File.exist?("#{@project_name}/Readme.md")).to be_truthy
  end
end


