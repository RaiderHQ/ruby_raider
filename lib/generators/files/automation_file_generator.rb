require_relative 'file_generator'
require_relative '../templates/automation/abstract_page_template'
require_relative '../templates/automation/abstract_component_template'
require_relative '../templates/automation/component_template'
require_relative '../templates/automation/page_template'

module RubyRaider
  class AutomationFileGenerator < FileGenerator
    class << self
      def generate_automation_files(name, automation, framework)
        generate_example_page(automation, name)
        generate_abstract_page(automation, framework, name)
        generate_example_component(name)
        generate_abstract_component(framework, name)
      end

      def generate_example_page(automation, name)
        generate_file('login_page.rb', "#{name}/page_objects/pages",
                      PageTemplate.new(automation: automation, name: name).parsed_body)
      end

      def generate_abstract_page(automation, framework, name)
        generate_file('abstract_page.rb', "#{name}/page_objects/abstract",
                      AbstractPageTemplate.new(automation: automation, framework: framework, name: name).parsed_body)
      end

      def generate_example_component(name)
        generate_file('header_component.rb',"#{name}/page_objects/components",
        ComponentTemplate.new.parsed_body)
      end

      def generate_abstract_component(framework, name)
        generate_file('abstract_component.rb',"#{name}/page_objects/abstract",
                      AbstractComponentTemplate.new(framework: framework).parsed_body)
      end
    end
  end
end
