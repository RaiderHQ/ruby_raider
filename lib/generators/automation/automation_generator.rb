# frozen_string_literal: true

require_relative '../generator'

class AutomationGenerator < Generator
  def generate_automation_files
    if mobile?
      generate_appium_settings
      generate_home_page
      generate_pdp_page
    else
      generate_visual_options
      generate_components
      generate_model_files
      generate_pages
    end

    generate_abstract_page
  end

  private

  def generate_pages
    generate_login_page
    generate_account_page
  end

  def generate_components
    generate_abstract_component
    generate_header_component
  end

  def generate_model_files
    generate_model_factory
    generate_model_data
  end

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

  def generate_login_page
    template('login_page.tt', "#{name}/page_objects/pages/login_page.rb")
  end

  def generate_account_page
    template('account_page.tt', "#{name}/page_objects/pages/account_page.rb")
  end

  def generate_home_page
    template('home_page.tt', "#{name}/page_objects/pages/home_page.rb")
  end

  def generate_pdp_page
    template('pdp_page.tt', "#{name}/page_objects/pages/pdp_page.rb")
  end

  def generate_header_component
    template('component.tt', "#{name}/page_objects/components/header_component.rb")
  end

  def generate_model_factory
    template('factory.tt', "#{name}/models/model_factory.rb")
  end

  def generate_model_data
    template('data.tt', "#{name}/models/data/users.yml")
  end
end
