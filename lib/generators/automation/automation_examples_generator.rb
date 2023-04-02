# frozen_string_literal: true

require_relative '../generator'

class AutomationExamplesGenerator < Generator
  def generate_login_page
    return unless (@_initializer.first & %w[android ios cross_platform]).empty?

    template('login_page.tt', "#{name}/page_objects/pages/login_page.rb")
  end

  def generate_home_page
    return if (@_initializer.first & %w[android ios cross_platform]).empty?

    template('home_page.tt', "#{name}/page_objects/pages/home_page.rb")
  end

  def generate_pdp_page
    return if (@_initializer.first & %w[android ios cross_platform]).empty?

    template('pdp_page.tt', "#{name}/page_objects/pages/pdp_page.rb")
  end

  def generate_header_component
    return unless (@_initializer.first & %w[android ios cross_platform]).empty?
    return if @_initializer.first.last

    template('component.tt', "#{name}/page_objects/components/header_component.rb")
  end

  def generate_app_page
    return unless @_initializer.first.last

    template('app_page.tt', "#{name}/page_objects/pages/app_page.rb")
  end
end
