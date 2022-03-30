require_relative '../lib/generators/projects/rspec_project_generator'
require_relative '../lib/generators/projects/cucumber_project_generator'
require 'fileutils'
require 'rspec'

RSpec.configure do |config|

  @project_name = 'test'

  config.before(:each) do
    RubyRaider::RspecProjectGenerator.generate_rspec_project(@project_name, automation: 'selenium')
  end

  #config.after(:each) do
  # FileUtils.rm_rf(@project_name)
  # end
end
