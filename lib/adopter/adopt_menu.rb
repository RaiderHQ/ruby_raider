# frozen_string_literal: true

require 'tty-prompt'
require_relative 'project_analyzer'
require_relative 'plan_builder'
require_relative 'migrator'

module Adopter
  class AdoptMenu
    WEB_AUTOMATIONS = %w[selenium capybara watir].freeze
    TEST_FRAMEWORKS = %w[rspec cucumber minitest].freeze
    CI_PLATFORMS = %w[github gitlab].freeze

    def initialize
      @prompt = TTY::Prompt.new
    end

    def run
      source_path = ask_source_path
      detection = preview_detection(source_path)
      target_automation = ask_target_automation(detection[:automation])
      target_framework = ask_target_framework(detection[:framework])
      output_path = ask_output_path
      ci_platform = ask_ci_platform(detection[:ci_platform])

      execute_adoption(
        source_path:,
        output_path:,
        target_automation:,
        target_framework:,
        ci_platform:
      )
    end

    # Programmatic entry point for raider_desktop and CLI --parameters
    def self.adopt(params)
      validate_params!(params)

      analysis = ProjectAnalyzer.new(params[:source_path]).analyze
      plan = PlanBuilder.new(analysis, params).build
      results = Migrator.new(plan).execute

      { plan:, results: }
    end

    def self.validate_params!(params)
      raise ArgumentError, 'source_path is required' unless params[:source_path]
      raise ArgumentError, 'output_path is required' unless params[:output_path]
      raise ArgumentError, 'target_automation is required' unless params[:target_automation]
      raise ArgumentError, 'target_framework is required' unless params[:target_framework]

      raise ArgumentError, "target_automation must be one of: #{WEB_AUTOMATIONS.join(', ')}" unless WEB_AUTOMATIONS.include?(params[:target_automation])

      return if TEST_FRAMEWORKS.include?(params[:target_framework])

      raise ArgumentError, "target_framework must be one of: #{TEST_FRAMEWORKS.join(', ')}"
    end

    private

    def ask_source_path
      path = @prompt.ask('Enter the path to your existing test project:') do |q|
        q.required true
        q.validate ->(input) { Dir.exist?(input) }
        q.messages[:valid?] = 'Directory does not exist: %<value>s'
      end
      File.expand_path(path)
    end

    def preview_detection(source_path)
      detection = ProjectDetector.detect(source_path)
      @prompt.say("\nDetected project settings:")
      @prompt.say("  Automation: #{detection[:automation] || 'unknown'}")
      @prompt.say("  Framework:  #{detection[:framework] || 'unknown'}")
      @prompt.say("  Browser:    #{detection[:browser] || 'not detected'}")
      @prompt.say("  URL:        #{detection[:url] || 'not detected'}")
      @prompt.say("  CI:         #{detection[:ci_platform] || 'none'}")
      @prompt.say('')
      detection
    end

    def ask_target_automation(detected)
      default = WEB_AUTOMATIONS.include?(detected) ? detected : nil
      @prompt.select('Select target automation framework:', WEB_AUTOMATIONS.map(&:capitalize),
                     default: default&.capitalize) do |menu|
        menu.choice :Quit, -> { exit }
      end.downcase
    end

    def ask_target_framework(detected)
      default = TEST_FRAMEWORKS.include?(detected) ? detected : nil
      @prompt.select('Select target test framework:', TEST_FRAMEWORKS.map(&:capitalize),
                     default: default&.capitalize) do |menu|
        menu.choice :Quit, -> { exit }
      end.downcase
    end

    def ask_output_path
      @prompt.ask('Enter the output path for the new Raider project:') do |q|
        q.required true
      end
    end

    def ask_ci_platform(detected)
      choices = [{ name: 'Github Actions', value: 'github' },
                 { name: 'Gitlab CI/CD', value: 'gitlab' },
                 { name: 'No CI', value: nil }]
      default = case detected
                when 'github' then 'Github Actions'
                when 'gitlab' then 'Gitlab CI/CD'
                end
      @prompt.select('Configure CI/CD?', choices, default:)
    end

    def execute_adoption(params)
      @prompt.say("\nAdopting project...")
      result = self.class.adopt(params)
      print_results(result[:plan], result[:results])
    rescue MobileProjectError => e
      @prompt.error(e.message)
    rescue StandardError => e
      @prompt.error("Adoption failed: #{e.message}")
    end

    def print_results(plan, results)
      @prompt.say("\nAdoption complete!")
      @prompt.say("  Pages converted:    #{results[:pages]}")
      @prompt.say("  Tests converted:    #{results[:tests]}")
      @prompt.say("  Features copied:    #{results[:features]}")
      @prompt.say("  Steps converted:    #{results[:steps]}")

      unless results[:errors].empty?
        @prompt.warn("\nErrors:")
        results[:errors].each { |e| @prompt.warn("  - #{e}") }
      end

      unless plan.warnings.empty?
        @prompt.warn("\nWarnings:")
        plan.warnings.each { |w| @prompt.warn("  - #{w}") }
      end

      @prompt.say("\nOutput: #{plan.output_path}")
      @prompt.say("Run: cd #{plan.output_path} && bundle install")
    end
  end
end
