# frozen_string_literal: true

require_relative 'generator'

class AutomationGenerator < Generator
  def generate_login_page
    return unless (@_initializer.first & %w[android ios cross_platform]).empty?

    template('automation/login_page.tt', "#{name}/page_objects/pages/login_page.rb")
  end

  def generate_abstract_page
    template('automation/abstract_page.tt', "#{name}/page_objects/abstract/abstract_page.rb")
  end

  def generate_home_page
    return if (@_initializer.first & %w[android ios cross_platform]).empty?

    template('automation/home_page.tt', "#{name}/page_objects/pages/home_page.rb")
  end

  def generate_pdp_page
    return if (@_initializer.first & %w[android ios cross_platform]).empty?

    template('automation/pdp_page.tt', "#{name}/page_objects/pages/pdp_page.rb")
  end

  def generate_header_component
    return unless (@_initializer.first & %w[android ios cross_platform]).empty?

    template('automation/component.tt', "#{name}/page_objects/components/header_component.rb")
  end

  def generate_abstract_component
    return unless (@_initializer.first & %w[android ios cross_platform]).empty?

    template('automation/abstract_component.tt', "#{name}/page_objects/abstract/abstract_component.rb")
  end

  def generate_appium_settings
    return if (@_initializer.first & %w[android ios cross_platform]).empty?

    template('automation/appium_caps.tt', "#{name}/config/capabilities.yml")
  end
end
