# frozen_string_literal: true

require_relative 'file_generator'

module RubyRaider
  class CommonFileGenerator < FileGenerator
      def generate_readme_file
        template('templates/common/read_me.tt', "#{name}/Readme.md")
      end

      def generate_config_file
        template('templates/common/config.tt', "#{name}/config.yml")
      end

      def generate_rake_file
        template('templates/common/rakefile.tt', "#{name}/Rakefile")
      end

      def generate_gemfile
        template('templates/common/gemfile.tt', "#{name}/Gemfile")
      end
    end
end
