# frozen_string_literal: true

module RubyRaider
  class ProjectGenerator
    class << self
      def create_children_folders(parent, folders)
        folders.each { |folder| Dir.mkdir "#{parent}/#{folder}" }
      end

      def install_gems(name)
        system "cd #{name} && gem install bundler && bundle install"
      end

      def create_project_folder(name)
        Dir.mkdir name.to_s
      end

      def create_base_folders
        raise 'Please specify the base folders for the projects'
      end

      def create_po_child_folders(automation, name)
        folders = %w[pages abstract]
        create_children_folders("#{name}/page_objects", folders)
        Dir.mkdir "#{name}/page_objects/components" if %w[selenium watir].include?(automation)
      end
    end
  end
end
