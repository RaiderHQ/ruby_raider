# frozen_string_literal: true

require_relative '../files/cucumber_file_generator'
require_relative 'project_generator'

module RubyRaider
  class CucumberProjectGenerator < ProjectGenerator
    class << self
      def generate_cucumber_project(automation, name)
        cucumber_folder_structure(automation, name)
        CucumberFileGenerator.generate_cucumber_files(automation, name)
        ProjectGenerator.install_gems(name)
      end

      def cucumber_folder_structure(automation, name)
        create_project_folder(name)
        create_base_folders(automation, name)
        create_features_child_folders(name)
        Dir.mkdir "#{name}/features/support/helpers"
        create_po_child_folders(automation, name)
        Dir.mkdir "#{name}/allure-results/screenshots"
      end

      def create_base_folders(automation, name)
        folders = %w[features page_objects allure-results]
        create_children_folders(name.to_s, folders)
        Dir.mkdir "#{name}/config" if %w[selenium watir].include?(automation)
      end

      def create_features_child_folders(name)
        folders = %w[step_definitions support]
        create_children_folders("#{name}/features", folders)
      end
    end
  end
end
