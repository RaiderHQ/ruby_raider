module RubyRaider
  class ProjectGenerator
    def self.create_children_folders(parent, folders)
      folders.each { |folder| Dir.mkdir "#{parent}/#{folder}" }
    end

    def self.install_gems(name)
      system "cd #{name} && gem install bundler && bundle install"
    end
  end
end
