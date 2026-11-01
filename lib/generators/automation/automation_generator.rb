# frozen_string_literal: true

require_relative '../generator'

class AutomationGenerator < Generator
  def generate_automation_files
    generate_appium_settings if mobile?
    generate_abstract_component unless mobile?
    examples? ? generate_examples : generate_empty_folders
    generate_abstract_page
  end

  private

  def generate_examples
    if mobile?
      generate_home_page
      generate_pdp_page
    else
      generate_header_component
      generate_model_files
      generate_pages
    end
  end

  # A skeleton keeps the folders for the pages and components it will grow with `raider g`
  def generate_empty_folders
    create_file("#{name}/page_objects/pages/.keep", '')
    create_file("#{name}/page_objects/components/.keep", '') unless mobile?
  end

  def generate_pages
    generate_login_page
    generate_account_page
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
