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
      if automation.include? 'appium'
        template('automation/home_page.tt', "#{name}/page_objects/pages/home_page.rb")
      end
    end

    def generate_header_component
      unless automation.include? 'appium'
        template('automation/component.tt', "#{name}/page_objects/components/header_component.rb")
      end
    end

    def generate_abstract_component
      unless automation.include? 'appium'
        template('automation/abstract_component.tt', "#{name}/page_objects/abstract/abstract_component.rb")
      end
    end

    def generate_confirmation_page
      if automation.include? 'appium'
        template('automation/confirmation_page.tt', "#{name}/page_objects/pages/confirmation_page.rb")
      end
    end

    def generate_appium_settings
      if automation.include? 'appium'
        template('automation/appium_settings.tt', "#{name}/appium.txt")
      end
    end
  end
end
