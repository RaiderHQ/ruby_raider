require_relative '../templates/helpers/allure_helper_template'
require_relative '../templates/helpers/browser_helper_template'
require_relative '../templates/helpers/driver_helper_template'
require_relative '../templates/helpers/pom_helper_template'
require_relative '../templates/helpers/raider_helper_template'
require_relative '../templates/helpers/spec_helper_template'
require_relative '../templates/helpers/selenium_helper_template'
require_relative '../templates/helpers/watir_helper_template'
require_relative 'file_generator'

module RubyRaider
  class HelpersFileGenerator < FileGenerator
    class << self
      def generate_helper_files(name, automation, framework)
        path = framework == 'rspec' ? "#{name}/helpers" : "#{name}/features/support/helpers"
        generate_raider_helper(automation, framework, path)
        generate_allure_helper(framework, path)
        generate_pom_helper(path)
        generate_spec_helper(automation, path) if framework == 'rspec'
        if automation == 'watir'
          generate_watir_helper(path)
          generate_browser_helper(path)
        else
          generate_selenium_helper(path)
          generate_driver_helper(path)
        end
      end

      def generate_raider_helper(automation, framework, path)
        generate_file('raider.rb', path,
                      RaiderHelperTemplate.new(automation: automation, framework: framework).parsed_body)
      end

      def generate_allure_helper(framework, path)
        generate_file('allure_helper.rb', path, AllureHelperTemplate.new(framework: framework).parsed_body)
      end

      def generate_browser_helper(path)
        generate_file('browser_helper.rb', path, BrowserHelperTemplate.new.parsed_body)
      end

      def generate_pom_helper(path)
        generate_file('pom_helper.rb', path, PomHelperTemplate.new.parsed_body)
      end

      def generate_spec_helper(automation, path)
        generate_file('spec_helper.rb', path, SpecHelperTemplate.new(automation: automation).parsed_body)
      end

      def generate_watir_helper(path)
        generate_file('watir_helper.rb', path, WatirHelperTemplate.new.parsed_body)
      end

      def generate_selenium_helper(path)
        generate_file('selenium_helper.rb', path, SeleniumHelperTemplate.new.parsed_body)
      end

      def generate_driver_helper(path)
        generate_file('driver_helper.rb', path, DriverHelperTemplate.new.parsed_body)
      end
    end
  end
end