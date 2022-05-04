# frozen_string_literal: true

require_relative 'generator'

module RubyRaider
  class CommonGenerator < Generator
      def generate_readme_file
        template('common/read_me.tt', "#{name}/Readme.md")
      end

      def generate_config_file
        template('common/config.tt', "#{name}/config.yml")
      end

      def generate_rake_file
        template('common/rakefile.tt', "#{name}/Rakefile")
      end

      def generate_gemfile
        template('common/gemfile.tt', "#{name}/Gemfile")
      end
    end
end
