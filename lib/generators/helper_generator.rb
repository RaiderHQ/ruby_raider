# frozen_string_literal: true

require_relative 'generator'

class HelpersGenerator < Generator
  def generate_helpers
    generate_browser_helper
    generate_driver_helper
    generate_appium_helper
    generate_allure_helper
    generate_debug_helper
    generate_visual_helper
    generate_performance_helper
    generate_spec_helper
  end

  private

  def generate_allure_helper
    template('helpers/allure_helper.tt', "#{name}/helpers/allure_helper.rb")
  end

  def generate_browser_helper
    return if selenium_based? || mobile?

    template('helpers/browser_helper.tt', "#{name}/helpers/browser_helper.rb")
  end

  def generate_spec_helper
    return if cucumber?

    template('helpers/spec_helper.tt', "#{name}/helpers/spec_helper.rb")
  end

  def generate_driver_helper
    return if watir?

    template('helpers/driver_helper.tt', "#{name}/helpers/driver_helper.rb")
  end

  def generate_appium_helper
    return unless cross_platform?

    template('helpers/appium_helper.tt', "#{name}/helpers/appium_helper.rb")
  end

  def generate_debug_helper
    return unless web?

    template('helpers/debug_helper.tt', "#{name}/helpers/debug_helper.rb")
  end

  def generate_visual_helper
    return unless visual_addon? && web?

    template('helpers/visual_helper.tt', "#{name}/helpers/visual_helper.rb")
  end

  def generate_performance_helper
    return unless lighthouse_addon? && web?

    template('helpers/performance_helper.tt', "#{name}/helpers/performance_helper.rb")
  end
end
