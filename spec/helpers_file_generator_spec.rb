require_relative '../lib/generators/files/helpers_file_generator'
require_relative 'spec_helper'

describe RubyRaider::HelpersFileGenerator do
  it 'creates a raider file' do
    expect(File.exist?("#{@project_name}/helpers/raider.rb")).to be_truthy
  end

  it 'creates an allure helper file' do
    expect(File.exist?("#{@project_name}/helpers/allure_helper.rb")).to be_truthy
  end

  it 'creates a browser helper file' do
    expect(File.exist?("#{@project_name}/helpers/browser_helper.rb")).to be_truthy
  end

  it 'creates a pom helper file' do
    expect(File.exist?("#{@project_name}/helpers/pom_helper.rb")).to be_truthy
  end

  it 'creates a spec helper file' do
    expect(File.exist?("#{@project_name}/helpers/spec_helper.rb")).to be_truthy
  end

  it 'creates a watir helper file' do
    expect(File.exist?("#{@project_name}/helpers/allure_helper.rb")).to be_truthy
  end
end



