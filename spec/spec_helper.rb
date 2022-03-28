require_relative '../lib/generators/projects/rspec_project_generator'
require_relative '../lib/generators/projects/cucumber_project_generator'
require 'fileutils'
require 'rspec'

RSpec.configure do |config|

  @project_name = 'test'

  config.before(:cucumber_selenium) do
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@project_name, automation: 'selenium')
  end

  config.before(:cucumber_watir) do
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@project_name)
  end

  config.before(:rspec_selenium) do
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@project_name)
  end

  config.before(:rspec_watir) do
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@project_name, automation: 'selenium')
  end

  config.before(:common) do
    RubyRaider::CucumberProjectGenerator.generate_cucumber_project(@project_name, automation: 'selenium')
  end

  config.after(:all) do
    FileUtils.rm_rf(@project_name)
  end
end
