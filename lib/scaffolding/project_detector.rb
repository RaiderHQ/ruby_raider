# frozen_string_literal: true

module ScaffoldProjectDetector
  AUTOMATION_GEMS = {
    'capybara' => 'capybara',
    'watir' => 'watir',
    'selenium-webdriver' => 'selenium',
    'appium_lib' => 'appium',
    'eyes_selenium' => 'selenium',
    'axe-core-rspec' => 'selenium',
    'axe-core-cucumber' => 'selenium'
  }.freeze

  FRAMEWORK_GEMS = {
    'rspec' => 'rspec',
    'cucumber' => 'cucumber',
    'minitest' => 'minitest'
  }.freeze

  module_function

  def detect
    gemfile = read_gemfile
    {
      automation: detect_automation(gemfile),
      framework: detect_framework(gemfile),
      has_spec: Dir.exist?('spec'),
      has_features: Dir.exist?('features'),
      has_test: Dir.exist?('test')
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

  def capybara?
    detect_automation == 'capybara'
  end

  def watir?
    detect_automation == 'watir'
  end

  def config
    return {} unless File.exist?('config/config.yml')

    YAML.safe_load(File.read('config/config.yml'), permitted_classes: [Symbol]) || {}
  rescue StandardError
    {}
  end
end
