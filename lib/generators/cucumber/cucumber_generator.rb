# frozen_string_literal: true

require_relative '../generator'

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

  def generate_visual_feature
    return unless visual_addon? && web?

    template('visual_feature.tt', "#{name}/features/visual.feature")
  end

  def generate_visual_steps
    return unless visual_addon? && web?

    template('visual_steps.tt', "#{name}/features/step_definitions/visual_steps.rb")
  end

  def generate_accessibility_feature
    return unless axe_addon? && web?

    template('accessibility_feature.tt', "#{name}/features/accessibility.feature")
  end

  def generate_accessibility_steps
    return unless axe_addon? && web?

    template('accessibility_steps.tt', "#{name}/features/step_definitions/accessibility_steps.rb")
  end

  def generate_performance_feature
    return unless lighthouse_addon? && web?

    template('performance_feature.tt', "#{name}/features/performance.feature")
  end

  def generate_performance_steps
    return unless lighthouse_addon? && web?

    template('performance_steps.tt', "#{name}/features/step_definitions/performance_steps.rb")
  end

  def template_name
    @template_name ||= (@_initializer.first & %w[android ios cross_platform]).empty? ? 'login' : 'home'
  end
end
