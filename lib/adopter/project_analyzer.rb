# frozen_string_literal: true

require_relative 'project_detector'

module Adopter
  class MobileProjectError < StandardError; end

  # :reek:TooManyMethods { enabled: false }
  class ProjectAnalyzer
    KNOWN_FRAMEWORK_GEMS = %w[
      activesupport allure-cucumber allure-rspec allure-minitest allure-ruby-commons
      appium_lib appium_console axe-core-rspec axe-core-selenium capybara
      cucumber eyes_selenium eyes_universal minitest minitest-reporters
      parallel_split_test parallel_tests rake reek rspec rubocop rubocop-rspec
      rubocop-minitest ruby_raider selenium-webdriver site_prism watir
    ].freeze

    PAGE_DSL_PATTERNS = {
      site_prism: /class\s+\w+\s*<\s*SitePrism::Page/,
      capybara: /include\s+Capybara::DSL|\.fill_in\b|\.click_on\b|\.click_button\b/,
      selenium: /\.find_element\s*\(|driver\.navigate/,
      watir: /browser\.text_field|browser\.button|browser\.element/
    }.freeze

    PAGE_CLASS_PATTERNS = [
      /class\s+\w+\s*<\s*SitePrism::Page/,
      /class\s+\w+\s*<\s*(?:Page|BasePage|AbstractPage)/,
      /include\s+Capybara::DSL/,
      /\.find_element\s*\(/,
      /browser\.text_field|browser\.button/,
      /def\s+(?:visit|login|click_|fill_|select_|navigate)/
    ].freeze

    TEST_FILE_PATTERNS = {
      rspec: { glob: '**/*_spec.rb', marker: /\b(?:describe|context|it)\b/ },
      cucumber_feature: { glob: '**/*.feature', marker: /\b(?:Feature|Scenario)\b/ },
      cucumber_step: { glob: '**/*_steps.rb', marker: /\b(?:Given|When|Then)\b/ },
      minitest: { glob: '**/test_*.rb', marker: /class\s+\w+\s*<\s*Minitest::Test/ },
      minitest_alt: { glob: '**/*_test.rb', marker: /class\s+\w+\s*<\s*Minitest::Test/ }
    }.freeze

    HELPER_ROLES = {
      driver: /module\s+DriverHelper|def\s+(?:driver|create_driver)\b/,
      browser: /module\s+BrowserHelper|def\s+(?:browser|create_browser)\b/,
      capybara: /Capybara\.configure|Capybara\.register_driver/,
      env: /^(?:Before|After)\s+do\b/,
      factory: /FactoryBot|ModelFactory|def\s+self\.for\b/,
      spec_helper: /RSpec\.configure|Minitest::Test/
    }.freeze

    def initialize(source_path, overrides = {})
      @source_path = source_path
      @overrides = overrides
    end

    def analyze
      detection = ProjectDetector.detect(@source_path)
      validate_web_only!(detection)

      {
        **detection,
        **@overrides.compact,
        pages: discover_pages,
        tests: discover_tests,
        helpers: discover_helpers,
        features: discover_features,
        step_definitions: discover_step_definitions,
        custom_gems: discover_custom_gems,
        source_dsl: detect_page_dsl
      }
    end

    private

    def validate_web_only!(detection)
      return unless detection[:automation] == 'appium'

      raise MobileProjectError,
            'Mobile (Appium) projects cannot be adopted. Only web-based projects are supported.'
    end

    # :reek:FeatureEnvy { enabled: false }
    def discover_pages
      page_path = detect_page_dir
      return [] unless page_path

      ruby_files_in(page_path).filter_map do |file|
        content = File.read(file)
        next unless page_like?(content)

        {
          path: relative_path(file),
          class_name: extract_class_name(content),
          base_class: extract_base_class(content),
          methods: extract_public_methods(content)
        }
      end
    end

    def discover_tests
      results = []
      TEST_FILE_PATTERNS.each do |type, config|
        Dir.glob(File.join(@source_path, config[:glob])).each do |file|
          content = File.read(file)
          next unless content.match?(config[:marker])

          results << {
            path: relative_path(file),
            type: type.to_s.split('_').first.to_sym,
            class_name: extract_class_name(content),
            test_methods: extract_test_methods(content, type)
          }
        end
      end
      results
    end

    # :reek:FeatureEnvy { enabled: false }
    def discover_helpers
      helper_files = Dir.glob(File.join(@source_path, '**', '*helper*.rb')) +
                     Dir.glob(File.join(@source_path, '**', 'support', '*.rb')) +
                     Dir.glob(File.join(@source_path, '**', 'env.rb'))

      helper_files.uniq.first(30).filter_map do |file|
        next unless File.file?(file)

        content = File.read(file)
        role = detect_helper_role(content)

        {
          path: relative_path(file),
          role: role,
          modules_defined: extract_modules(content)
        }
      end
    end

    def discover_features
      Dir.glob(File.join(@source_path, '**', '*.feature')).map do |file|
        {
          path: relative_path(file),
          scenarios: count_scenarios(File.read(file))
        }
      end
    end

    def discover_step_definitions
      Dir.glob(File.join(@source_path, '**', '*_steps.rb')).map do |file|
        {
          path: relative_path(file),
          steps: count_steps(File.read(file))
        }
      end
    end

    # :reek:NestedIterators { enabled: false }
    def discover_custom_gems
      gemfile = File.join(@source_path, 'Gemfile')
      return [] unless File.exist?(gemfile)

      ProjectDetector.send(:parse_gemfile, @source_path).reject do |gem_name|
        KNOWN_FRAMEWORK_GEMS.include?(gem_name)
      end
    end

    def detect_page_dsl
      page_files = discover_pages.map { |p| File.join(@source_path, p[:path]) }
      return :raw if page_files.empty?

      page_contents = page_files.first(20).map { |f| File.read(f) }.join("\n")

      PAGE_DSL_PATTERNS.each do |dsl, pattern|
        return dsl if page_contents.match?(pattern)
      end

      :raw
    end

    # --- File discovery helpers ---

    def detect_page_dir
      detected = ProjectDetector.detect_page_path(@source_path)
      return File.join(@source_path, detected) if detected

      # Fallback: scan all .rb files for page-like classes
      nil
    end

    def ruby_files_in(dir)
      Dir.glob(File.join(dir, '**', '*.rb'))
    end

    def relative_path(absolute)
      absolute.sub("#{@source_path}/", '')
    end

    # --- Content analysis helpers ---

    def page_like?(content)
      PAGE_CLASS_PATTERNS.any? { |pattern| content.match?(pattern) }
    end

    def extract_class_name(content)
      match = content.match(/class\s+(\w+)/)
      match&.[](1)
    end

    def extract_base_class(content)
      match = content.match(/class\s+\w+\s*<\s*([\w:]+)/)
      match&.[](1)
    end

    def extract_public_methods(content)
      in_private = false
      content.each_line.filter_map do |line|
        in_private = true if line.match?(/^\s*private\b/)
        next if in_private

        match = line.match(/^\s*def\s+(\w+)/)
        match[1] if match && match[1] != 'initialize'
      end
    end

    def extract_test_methods(content, type)
      case type
      when :rspec
        content.scan(/\bit\s+['"]([^'"]+)['"]/).flatten
      when :minitest, :minitest_alt
        content.scan(/def\s+(test_\w+)/).flatten
      when :cucumber_step
        content.scan(/(?:Given|When|Then)\(['"]([^'"]+)['"]/).flatten
      else
        []
      end
    end

    def extract_modules(content)
      content.scan(/module\s+(\w+)/).flatten
    end

    def detect_helper_role(content)
      HELPER_ROLES.each do |role, pattern|
        return role if content.match?(pattern)
      end
      :custom
    end

    def count_scenarios(content)
      content.scan(/^\s*Scenario/).length
    end

    def count_steps(content)
      content.scan(/^\s*(?:Given|When|Then|And|But)\b/).length
    end
  end
end
