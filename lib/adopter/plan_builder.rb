# frozen_string_literal: true

require_relative 'migration_plan'
require_relative 'converters/identity_converter'

module Adopter
  class PlanBuilder
    def initialize(analysis, params)
      @analysis = analysis
      @params = params
      @warnings = []
      @manual_actions = []
    end

    def build
      MigrationPlan.new(
        source_path: @params[:source_path],
        output_path: @params[:output_path],
        target_automation: @params[:target_automation],
        target_framework: @params[:target_framework],
        ci_platform: @params[:ci_platform],
        skeleton_structure: build_skeleton_structure,
        converted_pages: plan_page_conversions,
        converted_tests: plan_test_conversions,
        converted_features: plan_feature_conversions,
        converted_steps: plan_step_conversions,
        gemfile_additions: @analysis[:custom_gems] || [],
        config_overrides: extract_config_overrides,
        warnings: @warnings,
        manual_actions: @manual_actions
      )
    end

    private

    def build_skeleton_structure
      {
        automation: @params[:target_automation],
        framework: @params[:target_framework],
        name: @params[:output_path],
        ci_platform: @params[:ci_platform]
      }
    end

    def plan_page_conversions
      pages = @analysis[:pages] || []
      pages.map do |page|
        source_file = File.join(@params[:source_path], page[:path])
        content = File.read(source_file)
        converted = convert_page(content, page)

        ConvertedFile.new(
          output_path: raider_page_path(page[:class_name]),
          content: converted,
          source_file: page[:path],
          conversion_notes: page_conversion_notes
        )
      end
    end

    def plan_test_conversions
      tests = @analysis[:tests] || []
      return [] if target_cucumber?

      tests.reject { |t| t[:type] == :cucumber }.map do |test|
        source_file = File.join(@params[:source_path], test[:path])
        content = File.read(source_file)
        converted = convert_test(content, test)

        ConvertedFile.new(
          output_path: raider_test_path(test),
          content: converted,
          source_file: test[:path],
          conversion_notes: test_conversion_notes(test[:type])
        )
      end
    end

    def plan_feature_conversions
      return [] unless target_cucumber?

      features = @analysis[:features] || []
      features.map do |feature|
        source_file = File.join(@params[:source_path], feature[:path])
        content = File.read(source_file)

        ConvertedFile.new(
          output_path: raider_feature_path(feature[:path]),
          content:,
          source_file: feature[:path],
          conversion_notes: 'Feature file copied as-is'
        )
      end
    end

    def plan_step_conversions
      return [] unless target_cucumber?

      steps = @analysis[:step_definitions] || []
      steps.map do |step|
        source_file = File.join(@params[:source_path], step[:path])
        content = File.read(source_file)
        converted = convert_step_page_references(content)

        ConvertedFile.new(
          output_path: raider_step_path(step[:path]),
          content: converted,
          source_file: step[:path],
          conversion_notes: 'Step definitions with updated page references'
        )
      end
    end

    # --- Page conversion ---

    def convert_page(content, page)
      source_dsl = @analysis[:source_dsl]
      target = @params[:target_automation]

      if same_automation_dsl?(source_dsl, target)
        restructure_page(content)
      else
        convert_page_dsl(content, page, source_dsl, target)
      end
    end

    def convert_page_dsl(content, page, source_dsl, target)
      converter = find_page_converter(source_dsl, target)
      if converter
        converter.call(content, page)
      else
        add_warning("No converter for #{source_dsl} → #{target}. Page '#{page[:class_name]}' copied as-is.")
        restructure_page(content)
      end
    end

    def find_page_converter(source_dsl, target)
      key = :"#{normalize_dsl(source_dsl)}_to_#{target}"
      page_converters[key]
    end

    def page_converters
      @page_converters ||= {}
    end

    def register_page_converter(key, converter)
      page_converters[key] = converter
    end

    # --- Test conversion ---

    def convert_test(content, test)
      source_framework = test[:type]
      target = @params[:target_framework]

      if source_framework.to_s == target
        restructure_test(content)
      else
        convert_test_framework(content, test, source_framework, target)
      end
    end

    def convert_test_framework(content, test, source_framework, target)
      converter = find_test_converter(source_framework, target)
      if converter
        converter.call(content, test)
      else
        add_warning("No converter for #{source_framework} → #{target}. Test '#{test[:path]}' copied as-is.")
        restructure_test(content)
      end
    end

    def find_test_converter(source_framework, target)
      key = :"#{source_framework}_to_#{target}"
      test_converters[key]
    end

    def test_converters
      @test_converters ||= {}
    end

    # --- Restructuring (identity conversion) ---

    def identity_converter
      @identity_converter ||= Converters::IdentityConverter.new(@params[:target_automation])
    end

    def restructure_page(content)
      identity_converter.convert_page(content, {})
    end

    def restructure_test(content)
      identity_converter.convert_test(content, {})
    end

    def convert_step_page_references(content)
      identity_converter.convert_step(content)
    end

    # --- Path helpers ---

    def raider_page_path(class_name)
      filename = class_name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
      filename = filename.delete_suffix('_page')
      "#{@params[:output_path]}/page_objects/pages/#{filename}.rb"
    end

    def raider_test_path(test)
      basename = File.basename(test[:path], '.rb')
      target = @params[:target_framework]

      case target
      when 'rspec'
        name = basename.delete_prefix('test_').delete_suffix('_spec')
        "#{@params[:output_path]}/spec/#{name}_spec.rb"
      when 'minitest'
        name = basename.delete_prefix('test_').delete_suffix('_test').delete_suffix('_spec')
        "#{@params[:output_path]}/test/test_#{name}.rb"
      else
        "#{@params[:output_path]}/spec/#{basename}.rb"
      end
    end

    def raider_feature_path(source_path)
      filename = File.basename(source_path)
      "#{@params[:output_path]}/features/#{filename}"
    end

    def raider_step_path(source_path)
      filename = File.basename(source_path)
      "#{@params[:output_path]}/features/step_definitions/#{filename}"
    end

    # --- Config ---

    def extract_config_overrides
      overrides = {}
      overrides[:browser] = @params[:browser] || @analysis[:browser]
      overrides[:url] = @params[:url] || @analysis[:url]
      overrides.compact
    end

    # --- Helpers ---

    def same_automation_dsl?(source_dsl, target)
      normalize_dsl(source_dsl) == target
    end

    def normalize_dsl(dsl)
      case dsl
      when :site_prism then 'capybara'
      else dsl.to_s
      end
    end

    def target_cucumber?
      @params[:target_framework] == 'cucumber'
    end

    def page_conversion_notes
      source = @analysis[:source_dsl]
      target = @params[:target_automation]
      same_automation_dsl?(source, target) ? 'Restructured to Raider conventions' : "Converted from #{source} to #{target}"
    end

    def test_conversion_notes(source_type)
      target = @params[:target_framework]
      source_type.to_s == target ? 'Restructured to Raider conventions' : "Converted from #{source_type} to #{target}"
    end

    def add_warning(message)
      @warnings << message
    end
  end
end
