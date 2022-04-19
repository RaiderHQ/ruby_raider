# frozen_string_literal: true

require_relative 'file_generator'

module RubyRaider
  class AutomationFileGenerator < FileGenerator
    def generate_login_page
      template('templates/automation/login_page.tt', "#{name}/page_objects/pages/login_page.rb")
    end

    def generate_abstract_page
      template('templates/automation/abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
    end

    def generate_home_page
      template('templates/automation/home_page.tt', "#{name}/page_objects/pages/home_page.rb")
    end

    def generate_confirmation_page
      template('templates/automation/confirmation_page.tt',
               "#{name}/page_objects/pages/confirmation_page.rb")
    end

      def generate_header_component
        template('templates/automation/confirmation_page.tt',
                 "#{name}/page_objects/components/header_component.rb")
      end

      def generate_abstract_component
        template('templates/automation/abstract_component.tt',
                 "#{name}/page_objects/abstract/abstract_component.rb")
      end

      def generate_appium_settings
        template('templates/automation/appium_settings.tt', "#{name}/appium.txt")
      end
    end
end
