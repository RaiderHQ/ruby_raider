require_relative 'spec_helper'

describe RubyRaider::RspecProjectGenerator do
  it 'creates a project folder' do
    expect(Dir.exist?(@project_name)).to be_truthy
  end

  it 'creates a spec folder' do
    expect(Dir.exist?("#{@project_name}/spec")).to be_truthy
  end

  it 'creates a page objects folder' do
    expect(Dir.exist?("#{@project_name}/page_objects")).to be_truthy
  end

  it 'creates an abstract page object folder' do
    expect(Dir.exist?("#{@project_name}/page_objects/abstract")).to be_truthy
  end

  it 'creates a pages folder' do
    expect(Dir.exist?("#{@project_name}/page_objects/pages")).to be_truthy
  end

  it 'creates a helper folder' do
    expect(Dir.exist?("#{@project_name}/helpers")).to be_truthy
  end

  it 'creates a data folder' do
    expect(Dir.exist?("#{@project_name}/data")).to be_truthy
  end

  it 'creates a config folder' do
    expect(Dir.exist?("#{@project_name}/config")).to be_truthy
  end
end
