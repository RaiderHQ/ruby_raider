require_relative 'generators/projects/cucumber_project_generator'
require_relative 'generators/projects/project_generator'
require_relative 'generators/projects/rspec_project_generator'

module RubyRaider
  class << self
    def generate_menu
      MenuGenerator.generate_choice_menu
    end

    def generate_rspec_project(name)
      RspecProjectGenerator.generate_rspec_project(name)
    end
  end
end
