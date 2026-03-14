# frozen_string_literal: true

require 'yaml'

module ScaffoldProjectDetector
  AUTOMATION_GEMS = {
    'watir' => 'watir',
    'selenium-webdriver' => 'selenium',
    'appium_lib' => 'appium',
    'eyes_selenium' => 'selenium',
    'axe-core-rspec' => 'selenium',
    'axe-core-cucumber' => 'selenium'
  }.freeze

  FRAMEWORK_GEMS = {
    'rspec' => 'rspec',
    'cucumber' => 'cucumber'
  }.freeze

  CONFIG_PATH = 'config/config.yml'

  class Error < StandardError; end

  module_function

  def detect
    gemfile = read_gemfile
    {
      automation: detect_automation(gemfile),
      framework: detect_framework(gemfile),
      has_spec: Dir.exist?('spec'),
      has_features: Dir.exist?('features')
    }
  end

  def detect_automation(gemfile = read_gemfile)
    AUTOMATION_GEMS.each do |gem_name, automation|
      return automation if gemfile.include?("'#{gem_name}'") || gemfile.include?("\"#{gem_name}\"")
    end
    'selenium'
  end

  def detect_framework(gemfile = read_gemfile)
    FRAMEWORK_GEMS.each do |gem_name, framework|
      return framework if gemfile.include?("'#{gem_name}'") || gemfile.include?("\"#{gem_name}\"")
    end
    'rspec'
  end

  def read_gemfile
    return '' unless File.exist?('Gemfile')

    File.read('Gemfile')
  end

  def selenium?
    detect_automation == 'selenium'
  end

  def watir?
    detect_automation == 'watir'
  end

  # Validates that the current directory looks like a Ruby Raider project.
  # Returns an array of warning messages (empty = valid project).
  def validate_project
    warnings = []
    warnings << 'Gemfile not found. Are you in a Ruby Raider project directory?' unless File.exist?('Gemfile')
    unless File.exist?(CONFIG_PATH)
      warnings << "#{CONFIG_PATH} not found. Scaffolded pages won't include URL navigation methods."
    end
    warnings
  end

  # Loads and parses config/config.yml. Returns a hash.
  # Raises ScaffoldProjectDetector::Error on malformed YAML.
  def config
    return {} unless File.exist?(CONFIG_PATH)

    YAML.safe_load(File.read(CONFIG_PATH), permitted_classes: [Symbol]) || {}
  rescue Psych::SyntaxError => e
    raise Error, "#{CONFIG_PATH} has invalid YAML syntax: #{e.message}"
  end

  # Returns the custom path for a scaffold type from config, or nil.
  def config_path(type)
    config["#{type}_path"]
  end
end
