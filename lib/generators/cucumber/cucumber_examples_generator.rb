# frozen_string_literal: true

require_relative '../generator'

class CucumberExamplesGenerator < Generator
  def generate_feature
    template('feature.tt', "#{name}/features/#{template_name}.feature")
  end

  def generate_steps
    template('steps.tt', "#{name}/features/step_definitions/#{template_name}_steps.rb")
  end

  def template_name
    @template_name ||= (@_initializer.first & %w[android ios cross_platform]).empty? ? 'login' : 'home'
  end
end
