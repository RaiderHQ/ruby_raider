# frozen_string_literal: true

require_relative 'project_generator'
require_relative '../files/rspec_file_generator'

module RubyRaider
  class RspecProjectGenerator < ProjectGenerator
    class << self
      def generate_rspec_project(automation, name)
        rspec_folder_structure(automation, name)
        RspecFileGenerator.new
        RspecFileGenerator.invoke_all
      end

      def rspec_folder_structure(automation, name)
        create_project_folder(name)
        create_base_folders(automation, name)
        create_po_child_folders(automation, name)
      end

      def create_base_folders(automation, name)
        folders = %w[data page_objects helpers spec]
        create_children_folders(name, folders)
        Dir.mkdir "#{name}/config" if %w[selenium watir].include?(automation)
      end
    end
  end
end
