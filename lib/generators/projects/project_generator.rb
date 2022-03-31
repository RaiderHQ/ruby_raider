module RubyRaider
  class ProjectGenerator
    class << self
      def create_children_folders(parent, folders)
        folders.each { |folder| Dir.mkdir "#{parent}/#{folder}" }
      end

      def install_gems(name)
        system "cd #{name} && gem install bundler && bundle install"
      end
    end
  end
end
