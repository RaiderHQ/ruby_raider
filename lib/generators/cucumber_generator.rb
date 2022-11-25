# frozen_string_literal: true

require_relative 'generator'

class CucumberGenerator < Generator
  def generate_feature
    template('cucumber/feature.tt', "#{name}/features/#{template_name}.feature")
  end

  def generate_steps
    template('cucumber/steps.tt', "#{name}/features/step_definitions/#{template_name}_steps.rb")
  end

  def generate_env_file
    template('cucumber/env.tt', "#{name}/features/support/env.rb")
  end

  def generate_world
    template('cucumber/world.tt', "#{name}/world.rb")
  end

  def template_name
    @template_name ||= (@_initializer.first & %w[android ios cross_platform]).empty? ? 'login' : 'home'
  end
end
