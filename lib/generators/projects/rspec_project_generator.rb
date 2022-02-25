require_relative 'project_generator'
require_relative '../files/rspec_file_generator'

module RubyRaider
  class RspecProjectGenerator < ProjectGenerator
    def self.generate_rspec_project(name, automation: 'watir')
      rspec_folder_structure(name)
      rspec_files(name, automation)
    end

    def self.rspec_folder_structure(name)
      Dir.mkdir name.to_s
      folders = %w[config data page_objects helpers spec]
      create_children_folders(name, folders)
      pages = %w[pages abstract]
      create_children_folders("#{name}/page_objects", pages)
    end

    def self.rspec_files(name, automation)
      RspecFileGenerator.generate_rspec_files(name, automation)
    end
  end
end
