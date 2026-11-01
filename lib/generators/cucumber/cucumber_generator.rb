# frozen_string_literal: true

require_relative '../generator'

class CucumberGenerator < Generator
  def generate_feature
    return unless examples?

    template('feature.tt', "#{name}/features/#{template_name}.feature")
  end

  def generate_steps
    return unless examples?

    template('steps.tt', "#{name}/features/step_definitions/#{template_name}_steps.rb")
  end

  # A skeleton keeps an empty step_definitions/ for the steps it will grow with `raider g steps`
  def generate_empty_steps_folder
    return if examples?

    create_file("#{name}/features/step_definitions/.keep", '')
  end

  def generate_user_factory
    return unless examples?

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

  def generate_accessibility_feature
    return unless axe_addon? && web? && examples?

    template('accessibility_feature.tt', "#{name}/features/accessibility.feature")
  end

  def generate_accessibility_steps
    return unless axe_addon? && web? && examples?

    template('accessibility_steps.tt', "#{name}/features/step_definitions/accessibility_steps.rb")
  end

  def template_name
    @template_name ||= (@_initializer.first & %w[android ios cross_platform]).empty? ? 'login' : 'home'
  end
end
