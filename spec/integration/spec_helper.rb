# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/generators/invoke_generators'
require_relative 'settings_helper'

AUTOMATION_TYPES = %w[android ios selenium watir cross_platform capybara].freeze
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
  CAPYBARA       = AUTOMATION_TYPES[5]
end

# Lazy project generation — only generates a project the first time it's needed.
# Replaces the old before(:all) that generated all 54 combinations upfront.
module LazyProjectGenerator
  GENERATED = Set.new
  MUTEX = Mutex.new

  def ensure_project(framework:, automation:, ci_platform: nil)
    settings = create_settings(framework:, automation:, ci_platform:)
    project_name = settings[:name]

    MUTEX.synchronize do
      unless GENERATED.include?(project_name)
        generate_framework(settings)
        GENERATED.add(project_name)
      end
    end

    project_name
  end
end

RSpec.configure do |config|
  config.include(InvokeGenerators)
  config.include(SettingsHelper)
  config.include(LazyProjectGenerator)

  # rubocop:disable RSpec/BeforeAfterAll
  config.before(:all) do
    # Generate all projects upfront (preserves existing behavior).
    # Individual specs can also call ensure_project() for on-demand generation.
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        CI_PLATFORMS.each do |ci_platform|
          ensure_project(framework:, automation:, ci_platform:)
        end
      end
    end
  end

  config.after(:all) do
    LazyProjectGenerator::GENERATED.each do |project_name|
      FileUtils.rm_rf(project_name)
    end
    LazyProjectGenerator::GENERATED.clear
  end
  # rubocop:enable RSpec/BeforeAfterAll
end
