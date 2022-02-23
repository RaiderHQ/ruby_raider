module RubyRaider
  class ProjectGenerator
    def self.generate_file(name, path, content)
      file_path = "#{path}/#{name}"
      File.new(file_path, 'w+')
      File.write(file_path, content)
    end

    def self.create_children_folders(parent, folders)
      folders.each { |folder| Dir.mkdir "#{parent}/#{folder}" }
    end
  end
end
