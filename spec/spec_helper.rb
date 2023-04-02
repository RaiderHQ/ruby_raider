# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../lib/generators/invoke_generators'

AUTOMATION_TYPES = %w[android ios selenium watir cross_platform].freeze
FRAMEWORKS = %w[cucumber rspec].freeze

def create_settings(framework, automation, examples, visual)
  {
    automation: automation,
    examples: examples,
    framework: framework,
    name: "#{framework}_#{automation}#{'_visual' if visual}#{'_without_examples' unless examples}",
    visual: visual
  }
end

RSpec.configure do |config|
  config.include(InvokeGenerators)
  config.before(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        [true, false].product([true, false]) do |examples, visual|
          settings = create_settings(framework, automation, examples, visual)
          generate_framework(settings)
        end
      end
    end
  end

  config.after(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        [true, false].product([true, false]) do |examples, visual|
          settings = create_settings(framework, automation, examples, visual)
          FileUtils.rm_rf(settings[:name])
        end
      end
    end
  end
end
