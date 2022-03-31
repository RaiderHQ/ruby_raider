require_relative 'project_generator'
require_relative '../files/rspec_file_generator'

module RubyRaider
  class RspecProjectGenerator < ProjectGenerator
    class << self
      def generate_rspec_project(name, automation: 'watir')
        rspec_folder_structure(name)
        RspecFileGenerator.generate_rspec_files(name, automation)
        ProjectGenerator.install_gems(name)
      end

      def rspec_folder_structure(name)
        Dir.mkdir name.to_s
        folders = %w[config data page_objects helpers spec]
        create_children_folders(name, folders)
        pages = %w[pages components abstract]
        create_children_folders("#{name}/page_objects", pages)
      end
    end
  end
end
