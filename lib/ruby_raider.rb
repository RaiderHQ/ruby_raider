require_relative 'generators/menu_generator'
require_relative 'generators/projects/cucumber_project_generator'
require_relative 'generators/projects/project_generator'
require_relative 'generators/projects/rspec_project_generator'

module RubyRaider
  class << self
    def generate_project(project_name)
      MenuGenerator.generate_choice_menu(project_name)
    end
  end
end
