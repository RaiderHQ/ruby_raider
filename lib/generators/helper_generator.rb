# frozen_string_literal: true

require_relative 'generator'

class HelpersGenerator < Generator
  def generate_raider_helper
    template('helpers/raider_helper.tt', "#{name}/helpers/raider.rb")
  end

  def generate_allure_helper
    return if @_initializer.first.last

    template('helpers/allure_helper.tt', "#{name}/helpers/allure_helper.rb")
  end

  def generate_browser_helper
    template('helpers/browser_helper.tt', "#{name}/helpers/browser_helper.rb") if @_initializer.first.include?('watir')
  end

  def generate_spec_helper
    return if @_initializer.first.last

    template('helpers/spec_helper.tt', "#{name}/helpers/spec_helper.rb") if @_initializer.first.include?('rspec')
  end

  def generate_selenium_helper
    return unless @_initializer.first.include?('selenium')

    template('helpers/selenium_helper.tt', "#{name}/helpers/selenium_helper.rb")
  end

  def generate_driver_helper
    return if @_initializer.first.include?('watir')

    template('helpers/driver_helper.tt', "#{name}/helpers/driver_helper.rb")
  end

  def generate_appium_helper
    return unless @_initializer.first.include?('cross_platform')

    template('helpers/appium_helper.tt', "#{name}/helpers/appium_helper.rb")
  end

  def generate_visual_helper
    return unless @_initializer.first.last

    template('helpers/visual_helper.tt', "#{name}/helpers/visual_helper.rb")
  end

  def generate_visual_spec_helper
    return unless @_initializer.first.last

    template('helpers/visual_spec_helper.tt', "#{name}/helpers/spec_helper.rb")
  end

  def generate_logger
    template('helpers/raider_log_helper.tt', "#{name}/helpers/raider_log_helper.rb")
  end
end
