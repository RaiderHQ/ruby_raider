# frozen_string_literal: true

module Adopter
  # :reek:TooManyMethods { enabled: false }
  module ProjectDetector
    GEM_AUTOMATION_MAP = {
      'site_prism' => 'capybara',
      'capybara' => 'capybara',
      'selenium-webdriver' => 'selenium',
      'watir' => 'watir',
      'appium_lib' => 'appium',
      'eyes_selenium' => 'selenium',
      'axe-core-selenium' => 'selenium',
      'axe-core-rspec' => 'selenium'
    }.freeze

    GEM_FRAMEWORK_MAP = {
      'cucumber' => 'cucumber',
      'rspec' => 'rspec',
      'minitest' => 'minitest'
    }.freeze

    BROWSERS = %w[chrome firefox safari edge].freeze

    module_function

    def detect(path = '.')
      {
        automation: detect_automation(path),
        framework: detect_framework(path),
        page_path: detect_page_path(path),
        spec_path: detect_spec_path(path),
        feature_path: detect_feature_path(path),
        helper_path: detect_helper_path(path),
        browser: detect_browser(path),
        url: detect_url(path),
        ci_platform: detect_ci_platform(path)
      }.compact
    end

    def detect_automation(path)
      gems = parse_gemfile(path)
      GEM_AUTOMATION_MAP.each do |gem_name, automation|
        return automation if gems.include?(gem_name)
      end
      detect_automation_from_requires(path)
    end

    def detect_framework(path)
      gems = parse_gemfile(path)
      GEM_FRAMEWORK_MAP.each do |gem_name, framework|
        return framework if gems.include?(gem_name)
      end
      return 'rspec' if Dir.exist?(File.join(path, 'spec'))
      return 'cucumber' if Dir.exist?(File.join(path, 'features'))
      return 'minitest' if Dir.exist?(File.join(path, 'test'))

      nil
    end

    def detect_page_path(path)
      candidates = %w[page_objects/pages page_objects pages page]
      find_existing_dir(path, candidates)
    end

    def detect_spec_path(path)
      candidates = %w[spec spec/features spec/tests test tests]
      find_existing_dir(path, candidates)
    end

    def detect_feature_path(path)
      candidates = %w[features features/scenarios]
      find_existing_dir(path, candidates)
    end

    def detect_helper_path(path)
      candidates = %w[helpers support spec/support features/support]
      find_existing_dir(path, candidates)
    end

    # :reek:NestedIterators { enabled: false }
    def detect_browser(path)
      config_files = helper_and_config_files(path)
      config_files.each do |file|
        next unless File.exist?(file)

        content = File.read(file)
        BROWSERS.each do |browser|
          return browser if content.match?(/(?:browser|driver)\s*[:=]\s*[:'"]?#{browser}\b/i)
        end
      end
      nil
    end

    def detect_url(path)
      config_files = helper_and_config_files(path)
      config_files.each do |file|
        next unless File.exist?(file)

        content = File.read(file)
        match = content.match(%r{(?:base_url|url|app_host)\s*[:=]\s*['"]?(https?://[^\s'"]+)})
        return match[1] if match
      end
      nil
    end

    def detect_ci_platform(path)
      return 'github' if Dir.exist?(File.join(path, '.github', 'workflows'))
      return 'gitlab' if File.exist?(File.join(path, '.gitlab-ci.yml'))

      nil
    end

    def parse_gemfile(path)
      gemfile = File.join(path, 'Gemfile')
      return [] unless File.exist?(gemfile)

      File.readlines(gemfile).filter_map do |line|
        match = line.match(/^\s*gem\s+['"]([^'"]+)['"]/)
        match[1] if match
      end
    end

    def detect_automation_from_requires(path)
      ruby_files = Dir.glob(File.join(path, '**', '*.rb'))
      ruby_files.first(50).each do |file|
        content = File.read(file)
        return 'capybara' if content.include?("require 'capybara'") || content.include?("require 'site_prism'")
        return 'selenium' if content.include?("require 'selenium-webdriver'")
        return 'watir' if content.include?("require 'watir'")
        return 'appium' if content.include?("require 'appium_lib'")
      end
      nil
    end

    def find_existing_dir(path, candidates)
      candidates.each do |candidate|
        return candidate if Dir.exist?(File.join(path, candidate))
      end
      nil
    end

    def helper_and_config_files(path)
      explicit = [
        File.join(path, 'config', 'config.yml'),
        File.join(path, 'spec', 'spec_helper.rb'),
        File.join(path, 'test', 'test_helper.rb'),
        File.join(path, 'features', 'support', 'env.rb'),
        File.join(path, 'support', 'env.rb'),
        File.join(path, '.env')
      ]
      helpers = Dir.glob(File.join(path, '**', '*helper*.rb')).first(10)
      explicit + helpers
    end

    private_class_method :detect_automation_from_requires, :find_existing_dir,
                         :helper_and_config_files, :parse_gemfile
  end
end
