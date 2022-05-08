# frozen_string_literal: true

require_relative 'generator'

module RubyRaider
  class CucumberGenerator < Generator
    def generate_feature
      template('cucumber/feature.tt', "#{name}/features/login.feature")
    end

    def generate_steps
      template('cucumber/steps.tt', "#{name}/features/step_definitions/login_steps.rb")
    end

    def generate_env_file
      template('cucumber/env.tt', "#{name}/features/support/env.rb")
    end
  end
end
