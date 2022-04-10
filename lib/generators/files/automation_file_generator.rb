require_relative 'file_generator'
require_relative '../templates/automation/abstract_page_template'
require_relative '../templates/automation/abstract_component_template'
require_relative '../templates/automation/appium_settings_template'
require_relative '../templates/automation/component_template'
require_relative '../templates/automation/confirmation_page_template'
require_relative '../templates/automation/login_page_template'
require_relative '../templates/automation/home_page_template'

module RubyRaider
  class AutomationFileGenerator < FileGenerator
    class << self
      def generate_automation_files(automation, name, framework)
        generate_login_page(automation, name)
        generate_abstract_page(automation, framework, name)
        if %w[selenium watir].include?(automation)
          generate_example_component(name)
          generate_abstract_component(framework, name)
        else
          generate_home_page(name)
          generate_confirmation_page(name)
          generate_appium_settings(name)
        end
      end

      def generate_login_page(automation, name)
        generate_file('login_page.rb', "#{name}/page_objects/pages",
                      LoginPageTemplate.new(automation: automation, name: name).parsed_body)
      end

      def generate_abstract_page(automation, framework, name)
        generate_file('abstract_page.rb', "#{name}/page_objects/abstract",
                      AbstractPageTemplate.new(automation: automation, framework: framework, name: name).parsed_body)
      end

      def generate_home_page(name)
        generate_file('home_page.rb', "#{name}/page_objects/pages",
                      HomePageTemplate.new.parsed_body)
      end

      def generate_confirmation_page(name)
        generate_file('confirmation_page.rb', "#{name}/page_objects/pages",
                      ConfirmationPageTemplate.new.parsed_body)
      end

      def generate_example_component(name)
        generate_file('header_component.rb', "#{name}/page_objects/components",
                      ComponentTemplate.new.parsed_body)
      end

      def generate_abstract_component(framework, name)
        generate_file('abstract_component.rb', "#{name}/page_objects/abstract",
                      AbstractComponentTemplate.new(framework: framework).parsed_body)
      end

      def generate_appium_settings(name)
        generate_file('appium.txt', name.to_s, AppiumSettingsTemplate.new.parsed_body)
      end
    end
  end
end
