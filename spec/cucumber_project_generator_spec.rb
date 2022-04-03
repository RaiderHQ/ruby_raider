require_relative 'spec_helper'

describe RubyRaider::CucumberProjectGenerator do
  before(:all) do
    @name = 'Cucumber'
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@name, automation: 'selenium')
  end

  it 'creates a project folder' do
    expect(Dir.exist?(@name)).to be_truthy
  end

  it 'creates a features folder' do
    expect(Dir.exist?("#{@name}/features")).to be_truthy
  end

  it 'creates a config folder' do
    expect(Dir.exist?("#{@name}/config")).to be_truthy
  end

  it 'creates a page_objects object folder' do
    expect(Dir.exist?("#{@name}/page_objects")).to be_truthy
  end

  it 'creates an allure results folder' do
    expect(Dir.exist?("#{@name}/allure-results")).to be_truthy
  end

  it 'creates a step definitions folder' do
    expect(Dir.exist?("#{@name}/features/step_definitions")).to be_truthy
  end

  it 'creates a support folder' do
    expect(Dir.exist?("#{@name}/features/support")).to be_truthy
  end

  it 'creates a helpers folder' do
    expect(Dir.exist?("#{@name}/features/support/helpers")).to be_truthy
  end

  it 'creates an abstract folder' do
    expect(Dir.exist?("#{@name}/page_objects/abstract")).to be_truthy
  end

  it 'creates a pages folder' do
    expect(Dir.exist?("#{@name}/page_objects/pages")).to be_truthy
  end

  it 'creates a components folder' do
    expect(Dir.exist?("#{@name}/page_objects/components")).to be_truthy
  end

  it 'creates a screenshot folder' do
    expect(Dir.exist?("#{@name}/allure-results/screenshots")).to be_truthy
  end

  after(:all) do
    FileUtils.rm_rf(@name)
  end
end
