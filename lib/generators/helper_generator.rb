# frozen_string_literal: true

require_relative 'generator'

module RubyRaider
  class HelpersGenerator < Generator

    def generate_raider_helper
      template('helpers/raider_helper.tt', "#{name}/helpers/raider.rb")
    end

    def generate_allure_helper
      template('helpers/allure_helper.tt', "#{name}/helpers/allure_helper.rb")
    end

    def generate_browser_helper
      if @_initializer.first.include?('watir')
        template('helpers/browser_helper.tt', "#{name}/helpers/browser_helper.rb")
      end
    end

    def generate_pom_helper
      template('helpers/pom_helper.tt', "#{name}/helpers/pom_helper.rb")
    end

    def generate_spec_helper
      template('helpers/spec_helper.tt', "#{name}/helpers/spec_helper.rb")
    end

    def generate_watir_helper
      if @_initializer.first.include?('watir')
        template('helpers/watir_helper.tt', "#{name}/helpers/watir_helper.rb")
      end
    end

    def generate_selenium_helper
      if @_initializer.first.include?('selenium')
        template('helpers/selenium_helper.tt', "#{name}/helpers/selenium_helper.rb")
      end
    end

    def generate_driver_helper
      unless @_initializer.first.include?('watir')
        template('helpers/driver_helper.tt', "#{name}/helpers/driver_helper.rb")
      end
    end
  end
end
