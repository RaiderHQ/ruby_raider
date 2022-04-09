require_relative '../templates/common/config_template'
require_relative '../templates/common/gemfile_template'
require_relative '../templates/common/rake_file_template'
require_relative '../templates/common/read_me_template'
require_relative 'file_generator'

module RubyRaider
  class CommonFileGenerator < FileGenerator
    class << self
      def generate_common_files(name, framework)
        generate_config_file(name)
        generate_rake_file(name)
        generate_readme_file(name)
        generate_gemfile(framework, name)
      end

      def generate_readme_file(name)
        generate_file('Readme.md', name.to_s, ReadMeTemplate.new.parsed_body)
      end

      def generate_config_file(name)
        generate_file('config.yml', "#{name}/config", ConfigTemplate.new.parsed_body)
      end

      def generate_rake_file(name)
        generate_file('Rakefile', name.to_s, RakeFileTemplate.new.parsed_body)
      end

      def generate_gemfile(framework, name)
        generate_file('Gemfile',name.to_s, GemfileTemplate.new(framework: framework).parsed_body)
      end
    end
  end
end