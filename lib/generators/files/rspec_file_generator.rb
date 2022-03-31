require_relative '../templates/rspec/example_spec_template'
require_relative '../templates/rspec/base_spec_template'
require_relative 'automation_file_generator'
require_relative 'common_file_generator'
require_relative 'file_generator'
require_relative 'helpers_file_generator'

module RubyRaider
  class RspecFileGenerator < FileGenerator
    class << self
      def generate_rspec_files(name, automation)
        AutomationFileGenerator.generate_automation_files(name, automation, 'rspec')
        CommonFileGenerator.generate_common_files(name, 'rspec')
        HelpersFileGenerator.generate_helper_files(name, automation, 'rspec')
        generate_base_spec(name)
        generate_example_spec(name)
      end

      def generate_example_spec(name)
        generate_file('login_page_spec.rb', "#{name}/spec", ExampleSpecTemplate.new.parsed_body)
      end

      def generate_base_spec(name)
        generate_file('base_spec.rb', "#{name}/spec", BaseSpecTemplate.new.parsed_body)
      end
    end
  end
end
