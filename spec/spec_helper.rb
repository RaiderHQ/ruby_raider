# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../lib/generators/invoke_generators'
require_relative 'support/settings_helper'

AUTOMATION_TYPES = %w[android ios selenium watir cross_platform].freeze
FRAMEWORKS = %w[cucumber rspec].freeze

RSpec.configure do |config|
  config.include(InvokeGenerators)
  config.include(SettingsHelper)
  config.before(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        [true, false].each do |visual|
          settings = create_settings(framework: framework, automation: automation, visual: visual, axe: axe_support)
          generate_framework(settings)
        end
      end
    end
  end

  config.after(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        [true, false].each do |visual|
          settings = create_settings(framework: framework, automation: automation, visual: visual)
          FileUtils.rm_rf(settings[:name])
        end
      end
    end
  end
end
