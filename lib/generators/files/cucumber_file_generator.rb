# frozen_string_literal: true

require_relative 'file_generator'

module RubyRaider
  class CucumberFileGenerator < FileGenerator
    def generate_feature
      template('templates/cucumber/feature.tt', "#{name}/features/login.feature")
    end

    def generate_steps
      template('templates/cucumber/steps.tt', "#{name}/features/step_definitions/login_steps")
    end

    def generate_env_file
      template('templates/cucumber/env.tt', "#{name}/features/support/env.rb")
    end
  end
end
