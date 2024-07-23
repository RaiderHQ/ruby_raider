# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/generators/invoke_generators'
require_relative 'settings_helper'

AUTOMATION_TYPES = %w[android ios selenium watir cross_platform axe applitools].freeze
FRAMEWORKS = %w[cucumber rspec].freeze

RSpec.configure do |config|
  config.include(InvokeGenerators)
  config.include(SettingsHelper)
  # rubocop:disable RSpec/BeforeAfterAll
  config.before(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        settings = create_settings(framework:, automation:)
        generate_framework(settings)
      end
    end
  end

  config.after(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        settings = create_settings(framework:, automation:)
        FileUtils.rm_rf(settings[:name])
      end
    end
  end
end
# rubocop:enable RSpec/BeforeAfterAll
