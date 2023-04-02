# frozen_string_literal: true

require_relative '../generator'

class AutomationGenerator < Generator
  def generate_abstract_page
    template('abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
  end

  def generate_abstract_component
    return unless (@_initializer.first & %w[android ios cross_platform]).empty?
    return if @_initializer.first.last

    template('abstract_component.tt', "#{name}/page_objects/abstract/abstract_component.rb")
  end

  def generate_appium_settings
    return if (@_initializer.first & %w[android ios cross_platform]).empty?

    template('appium_caps.tt', "#{name}/config/capabilities.yml")
  end

  def generate_visual_options
    return unless @_initializer.first.last

    template('visual_options.tt', "#{name}/config/options.yml")
  end
end
