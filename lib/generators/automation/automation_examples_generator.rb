# frozen_string_literal: true

require_relative '../generator'

class AutomationExamplesGenerator < Generator
  def generate_example_files
    if mobile_platform?
      generate_login_page
      generate_header_component unless visual_selected?
    else
      generate_home_page
      generate_pdp_page
    end

    generate_app_page if visual_selected?
  end

  private

  def generate_login_page
    template('login_page.tt', "#{name}/page_objects/pages/login_page.rb")
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

  def generate_app_page
    template('app_page.tt', "#{name}/page_objects/pages/app_page.rb")
  end
end
