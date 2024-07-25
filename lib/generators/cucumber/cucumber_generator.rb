# frozen_string_literal: true

require_relative '../generator'

module RubyRaider
  class CucumberGenerator < Generator
    def generate_feature
      template('feature.tt', "#{name}/features/#{template_name}.feature")
    end

    def generate_steps
      template('steps.tt', "#{name}/features/step_definitions/#{template_name}_steps.rb")
    end

    def generate_user_factory
      template('user_factory.tt', "#{name}/models/user_factory.rb")
    end

    def generate_env_file
      template('env.tt', "#{name}/features/support/env.rb")
    end

    def generate_world
      template('world.tt', "#{name}/features/support/world.rb")
    end

    def generate_cucumber_file
      template('cucumber.tt', "#{name}/cucumber.yml")
    end

    def template_name
      @template_name ||= (@_initializer.first & %w[android ios cross_platform]).empty? ? 'login' : 'home'
    end
  end
end
