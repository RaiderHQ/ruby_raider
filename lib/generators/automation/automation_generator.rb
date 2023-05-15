# frozen_string_literal: true

require_relative '../generator'

class AutomationGenerator < Generator
  def generate_automation_files
    if mobile?
      generate_appium_settings
    else
      generate_abstract_component
      generate_visual_options
    end

    generate_abstract_page
  end


  private

  def generate_abstract_page
    template('abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
  end

  def generate_abstract_component
    template('abstract_component.tt', "#{name}/page_objects/abstract/abstract_component.rb")
  end

  def generate_appium_settings
    template('appium_caps.tt', "#{name}/config/capabilities.yml")
  end

  def generate_visual_options
    return unless visual?

    template('visual_options.tt', "#{name}/config/options.yml")
  end
end
