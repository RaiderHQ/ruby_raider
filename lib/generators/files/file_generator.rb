require 'thor'

module RubyRaider
  class FileGenerator
    def self.generate_file(name, path, content)
      file_path = "#{path}/#{name}"
      File.new(file_path, 'w+')
      File.write(file_path, content)
    end
  end
end
