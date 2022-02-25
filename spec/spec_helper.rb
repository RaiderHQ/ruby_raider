require_relative '../lib/generators/projects/rspec_project_generator'
require 'fileutils'
require 'rspec'

RSpec.configure do |config|
  config.before(:all) do
    @project_name = 'test'
    RubyRaider::RspecProjectGenerator.generate_rspec_project @project_name
  end

  config.after(:all) do
   FileUtils.rm_rf(@project_name)
  end
end
