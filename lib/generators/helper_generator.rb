# frozen_string_literal: true

require_relative 'generator'

class HelpersGenerator < Generator
  def generate_helpers
    generate_driver_helper
    generate_appium_helper
    generate_spec_helper
    generate_video_helper
    generate_session_state
    generate_trace_helper
    generate_network_helper
    generate_screenshot_helper
  end

  private

  def generate_spec_helper
    template('helpers/spec_helper.tt', "#{name}/helpers/spec_helper.rb")
  end

  def generate_driver_helper
    template('helpers/driver_helper.tt', "#{name}/helpers/driver_helper.rb")
  end

  def generate_video_helper
    template('helpers/video_helper.tt', "#{name}/helpers/video_helper.rb")
  end

  def generate_session_state
    return if mobile?

    template('helpers/session_state.tt', "#{name}/helpers/session_state.rb")
  end

  def generate_trace_helper
    return unless trace_helper?

    template('helpers/trace_helper.tt', "#{name}/helpers/trace_helper.rb")
  end

  def generate_network_helper
    return unless network_helper?

    template('helpers/network_helper.tt', "#{name}/helpers/network_helper.rb")
  end

  def generate_screenshot_helper
    return unless screenshot_helper?

    template('helpers/screenshot_helper.tt', "#{name}/helpers/screenshot_helper.rb")
  end

  def generate_appium_helper
    return unless cross_platform?

    template('helpers/appium_helper.tt', "#{name}/helpers/appium_helper.rb")
  end
end
