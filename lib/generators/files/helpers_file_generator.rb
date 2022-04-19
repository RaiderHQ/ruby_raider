# frozen_string_literal: true

require_relative 'file_generator'

module RubyRaider
  class HelpersFileGenerator < FileGenerator

    def generate_raider_helper
      template('templates/helpers/raider_helper.tt', "#{name}/helpers/raider_helper.rb")
    end

    def generate_allure_helper
      template('templates/helpers/allure_helper.tt', "#{name}/helpers/allure_helper.rb")
    end

    def generate_browser_helper
      template('templates/helpers/browser_helper.tt', "#{name}/helpers/browser_helper.rb")
    end

    def generate_pom_helper
      template('templates/helpers/pom_helper.tt', "#{name}/helpers/pom_helper.rb")
    end

    def generate_spec_helper
      template('templates/helpers/spec_helper.tt', "#{name}/helpers/spec_helper.rb")
    end

    def generate_watir_helper
      template('templates/helpers/watir_helper.tt', "#{name}/helpers/watir_helper.rb")
    end

    def generate_selenium_helper(path)
      template('templates/helpers/selenium_helper.tt', "#{name}/helpers/selenium_helper.rb")
    end

    def generate_driver_helper(automation, path)
      template('templates/helpers/driver_helper.tt', "#{name}/helpers/driver_helper.rb")
    end
  end
end
