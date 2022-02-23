require_relative 'project_generator'

module RubyRaider
  class CucumberGenerator
    def cucumber_folder_structure(name)
      Dir.mkdir name.to_s
      Dir.mkdir "#{name}/features"
      folders = %w[steps_definitions support]
      create_children_folders("#{name}/features", folders)
      Dir.mkdir "#{name}/features/support/helpers"
      Dir.mkdir "#{name}/page_objects"
    end
  end
end
