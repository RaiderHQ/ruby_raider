require_relative '../files/cucumber_file_generator'
require_relative 'project_generator'

module RubyRaider
  class CucumberProjectGenerator < ProjectGenerator
    class << self
      def generate_cucumber_project(name, automation: 'watir')
        cucumber_folder_structure(name)
        CucumberFileGenerator.generate_cucumber_files(name, automation)
        ProjectGenerator.install_gems(name)
      end

      def cucumber_folder_structure(name)
        Dir.mkdir name.to_s
        folders = %w[features config page_objects allure-results]
        create_children_folders("#{name}", folders)
        folders = %w[step_definitions support]
        create_children_folders("#{name}/features", folders)
        Dir.mkdir "#{name}/features/support/helpers"
        folders = %w[abstract pages components]
        create_children_folders("#{name}/page_objects", folders)
        Dir.mkdir "#{name}/allure-results/screenshots"
      end
    end
  end
end
