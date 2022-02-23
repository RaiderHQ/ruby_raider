require_relative 'generators/project/cucumber_generator'
require_relative 'generators/project/project_generator'
require_relative 'generators/project/rspec_generator'

module RubyRaider
  class << self
    def generate_menu
      MenuGenerator.generate_choice_menu
    end

    def generate_project(name)
      RspecGenerator.generate_rspec_project name
    end
  end
end
