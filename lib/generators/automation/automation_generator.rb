# frozen_string_literal: true

require_relative '../generator'

class AutomationGenerator < Generator
  def generate_abstract_page
    template('abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
  end

  def generate_abstract_component
    return if mobile_platform?

    template('abstract_component.tt', "#{name}/page_objects/abstract/abstract_component.rb")
  end

  def generate_appium_settings
    return unless mobile_platform?

    template('appium_caps.tt', "#{name}/config/capabilities.yml")
  end

  def generate_visual_options
    return unless visual_selected?

    template('visual_options.tt', "#{name}/config/options.yml")
  end
end
