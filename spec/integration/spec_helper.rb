# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/generators/invoke_generators'
require_relative 'settings_helper'

AUTOMATION_TYPES = %w[android ios selenium watir cross_platform axe applitools capybara].freeze
FRAMEWORKS = %w[cucumber rspec minitest].freeze
CI_PLATFORMS = [nil, 'github', 'gitlab'].freeze

# Named constants for readable spec references — no more fragile numeric indices
module FrameworkIndex
  CUCUMBER  = FRAMEWORKS[0]
  RSPEC     = FRAMEWORKS[1]
  MINITEST  = FRAMEWORKS[2]
end

module AutomationIndex
  ANDROID        = AUTOMATION_TYPES[0]
  IOS            = AUTOMATION_TYPES[1]
  SELENIUM       = AUTOMATION_TYPES[2]
  WATIR          = AUTOMATION_TYPES[3]
  CROSS_PLATFORM = AUTOMATION_TYPES[4]
  AXE            = AUTOMATION_TYPES[5]
  APPLITOOLS     = AUTOMATION_TYPES[6]
  CAPYBARA       = AUTOMATION_TYPES[7]
end

RSpec.configure do |config|
  config.include(InvokeGenerators)
  config.include(SettingsHelper)

  # rubocop:disable RSpec/BeforeAfterAll
  config.before(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        CI_PLATFORMS.each do |ci_platform|
          settings = create_settings(framework:, automation:, ci_platform:)
          generate_framework(settings)
        end
      end
    end
  end

  config.after(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        CI_PLATFORMS.each do |ci_platform|
          settings = create_settings(framework:, automation:, ci_platform:)
          FileUtils.rm_rf(settings[:name])
        end
      end
    end
  end
  # rubocop:enable RSpec/BeforeAfterAll
end
