# frozen_string_literal: true

require 'fileutils'
require 'rspec'

RSpec.configure do |config|
  config.before(:all) do
    @automation_types = %w[android ios selenium watir]
    @frameworks = %w[cucumber rspec]
    @frameworks.each do |framework|
      @automation_types.each do |automation|
        described_class.new([automation, framework, "#{framework}_#{automation}"]).invoke_all
      end
    end
  end

  config.after(:all) do
    @frameworks.each do |framework|
      @automation_types.each { |automation| FileUtils.rm_rf("#{framework}_#{automation}") }
    end
  end
end
