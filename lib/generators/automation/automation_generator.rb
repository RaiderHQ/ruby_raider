# frozen_string_literal: true

require_relative '../generator'

class AutomationGenerator < Generator
  def generate_abstract_page
    template('abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
  end

  def generate_abstract_component
    return if mobile?

    template('abstract_component.tt', "#{name}/page_objects/abstract/abstract_component.rb")
  end

  def generate_appium_settings
    return unless mobile?

    template('appium_caps.tt', "#{name}/config/capabilities.yml")
  end

  def generate_visual_options
    return unless mobile?

    template('visual_options.tt', "#{name}/config/options.yml")
  end
end
