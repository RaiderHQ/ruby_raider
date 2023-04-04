# frozen_string_literal: true

require_relative 'generator'

class HelpersGenerator < Generator
  def generate_helpers
    generate_raider_helper
    generate_browser_helper
    generate_driver_helper
    generate_appium_helper

    if visual_selected?
      generate_visual_helper
      generate_visual_spec_helper
    else
      generate_allure_helper
      generate_spec_helper
    end
  end

  private

  def generate_raider_helper
    template('helpers/raider_helper.tt', "#{name}/helpers/raider.rb")
  end

  def generate_allure_helper
    template('helpers/allure_helper.tt', "#{name}/helpers/allure_helper.rb")
  end

  def generate_browser_helper
    template('helpers/browser_helper.tt', "#{name}/helpers/browser_helper.rb") if args.include?('watir')
  end

  def generate_spec_helper
    template('helpers/spec_helper.tt', "#{name}/helpers/spec_helper.rb") if args.include?('rspec')
  end

  def generate_driver_helper
    return if args.include?('watir')

    template('helpers/driver_helper.tt', "#{name}/helpers/driver_helper.rb")
  end

  def generate_appium_helper
    return unless args.include?('cross_platform')

    template('helpers/appium_helper.tt', "#{name}/helpers/appium_helper.rb")
  end

  def generate_visual_helper
    template('helpers/visual_helper.tt', "#{name}/helpers/visual_helper.rb")
  end

  def generate_visual_spec_helper
    template('helpers/visual_spec_helper.tt', "#{name}/helpers/spec_helper.rb")
  end
end
