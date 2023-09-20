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
    template('page.tt', "#{name}/page_objects/abstract/page.rb")
  end

  def generate_abstract_component
    template('component.tt', "#{name}/page_objects/abstract/component.rb")
  end

  def generate_appium_settings
    template('appium_caps.tt', "#{name}/config/capabilities.yml")
  end

  def generate_visual_options
    return unless visual?

    template('visual_options.tt', "#{name}/config/options.yml")
  end

  def generate_login_page
    template('login.tt', "#{name}/page_objects/pages/login.rb")
  end

  def generate_account_page
    template('account.tt', "#{name}/page_objects/pages/account.rb")
  end

  def generate_home_page
    template('home.tt', "#{name}/page_objects/pages/home.rb")
  end

  def generate_pdp_page
    template('pdp.tt', "#{name}/page_objects/pages/pdp.rb")
  end

  def generate_header_component
    template('header.tt', "#{name}/page_objects/components/header.rb")
  end

  def generate_model_factory
    template('factory.tt', "#{name}/models/model_factory.rb")
  end

  def generate_model_data
    template('data.tt', "#{name}/models/data/users.yml")
  end
end
