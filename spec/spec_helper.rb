# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../lib/generators/menu_generator'

AUTOMATION_TYPES = %w[android ios selenium watir cross_platform].freeze
FRAMEWORKS = %w[cucumber rspec].freeze

RSpec.configure do |config|
  config.before(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        MenuGenerator.new("#{framework}_#{automation}").generate_framework(automation, framework, false)
      end
    end
  end

  config.after(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each { |automation| FileUtils.rm_rf("#{framework}_#{automation}") }
    end
  end
end
