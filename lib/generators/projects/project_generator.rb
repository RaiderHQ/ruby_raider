module RubyRaider
  class ProjectGenerator
    def self.create_children_folders(parent, folders)
      folders.each { |folder| Dir.mkdir "#{parent}/#{folder}" }
    end
  end
end
