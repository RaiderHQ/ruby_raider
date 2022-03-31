require_relative '../templates/cucumber/env_template'
require_relative '../templates/cucumber/example_feature_template'
require_relative '../templates/cucumber/example_steps_template'
require_relative 'file_generator'

module RubyRaider
  class CucumberFileGenerator < FileGenerator
    class << self
      def generate_cucumber_files(name, automation)
        AutomationFileGenerator.generate_automation_files(name, automation, 'framework')
        CommonFileGenerator.generate_common_files(name, 'cucumber')
        HelpersFileGenerator.generate_helper_files(name, automation, 'cucumber')
        generate_env_file(name, automation)
        generate_example_feature(name)
        generate_example_steps(name)
      end

      def generate_example_feature(name)
        generate_file('login.feature', "#{name}/features", ExampleFeatureTemplate.new.parsed_body)
      end

      def generate_example_steps(name)
        generate_file('login_steps.rb', "#{name}/features/step_definitions",
                      ExampleStepsTemplate.new.parsed_body)
      end

      def generate_env_file(automation, name)
        generate_file('env.rb', "#{name}/features/support",
                      ExampleStepsTemplate.new(automation: automation).parsed_body)
      end
    end
  end
end
