# frozen_string_literal: true

require_relative 'generator'

module RubyRaider
  class AutomationGenerator < Generator
    def generate_login_page
      template('automation/login_page.tt', "#{name}/page_objects/pages/login_page.rb")
    end

    def generate_abstract_page
      template('automation/abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
    end

    def generate_home_page
      template('automation/home_page.tt', "#{name}/page_objects/pages/home_page.rb")
    end

    def generate_header_component
      template('automation/component.tt',
               "#{name}/page_objects/components/header_component.rb")
    end

    def generate_abstract_component
      template('automation/abstract_component.tt',
               "#{name}/page_objects/abstract/abstract_component.rb")
    end


      def generate_confirmation_page
        template('automation/confirmation_page.tt',
                 "#{name}/page_objects/pages/confirmation_page.rb") if @_initializer.first.include?('appium_ios')
      end

      def generate_appium_settings
        template('automation/appium_settings.tt', "#{name}/appium.txt") if @_initializer.first.include?('appium_ios')
      end
  end
end
