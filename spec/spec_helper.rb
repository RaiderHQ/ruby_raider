# frozen_string_literal: true

require 'fileutils'
require 'rspec'

AUTOMATION_TYPES = %w[android ios selenium watir].freeze
FRAMEWORKS = %w[cucumber rspec].freeze

RSpec.configure do |config|
  config.before(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each do |automation|
        described_class.new([automation, framework, "#{framework}_#{automation}"]).invoke_all
      end
    end
  end

  config.after(:all) do
    FRAMEWORKS.each do |framework|
      AUTOMATION_TYPES.each { |automation| FileUtils.rm_rf("#{framework}_#{automation}") }
    end
  end
end