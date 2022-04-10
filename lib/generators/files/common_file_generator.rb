require_relative '../templates/common/config_template'
require_relative '../templates/common/gemfile_template'
require_relative '../templates/common/rake_file_template'
require_relative '../templates/common/read_me_template'
require_relative 'file_generator'

module RubyRaider
  class CommonFileGenerator < FileGenerator
    class << self
      def generate_common_files(automation, name, framework)
        if %w[selenium watir].include?(automation)
          generate_config_file(name)
          generate_rake_file(name)
        end

        generate_readme_file(name)
        generate_gemfile(automation, framework, name)
      end

      def generate_readme_file(name)
        generate_file('Readme.md', name.to_s, ReadMeTemplate.new.parsed_body)
      end

      def generate_config_file(name)
        generate_file('config.yml', "#{name}/config", ConfigTemplate.new.parsed_body)
      end

      def generate_rake_file(name)
        generate_file('Rakefile', name.to_s, ConfigTemplate.new.parsed_body)
      end

      def generate_gemfile(automation, framework, name)
        generate_file('Gemfile',name.to_s,
                      GemfileTemplate.new(automation: automation, framework: framework).parsed_body)
      end
    end
  end
end