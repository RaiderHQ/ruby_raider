# frozen_string_literal: true

module Adopter
  class MigrationPlan
    attr_reader :source_path, :output_path, :target_automation, :target_framework,
                :ci_platform, :skeleton_structure, :converted_pages, :converted_tests,
                :converted_features, :converted_steps, :gemfile_additions,
                :config_overrides, :warnings, :manual_actions

    def initialize(attrs = {})
      @source_path = attrs[:source_path]
      @output_path = attrs[:output_path]
      @target_automation = attrs[:target_automation]
      @target_framework = attrs[:target_framework]
      @ci_platform = attrs[:ci_platform]
      @skeleton_structure = attrs[:skeleton_structure] || {}
      @converted_pages = attrs[:converted_pages] || []
      @converted_tests = attrs[:converted_tests] || []
      @converted_features = attrs[:converted_features] || []
      @converted_steps = attrs[:converted_steps] || []
      @gemfile_additions = attrs[:gemfile_additions] || []
      @config_overrides = attrs[:config_overrides] || {}
      @warnings = attrs[:warnings] || []
      @manual_actions = attrs[:manual_actions] || []
    end

    def to_h
      {
        source_path:,
        output_path:,
        target_automation:,
        target_framework:,
        ci_platform:,
        skeleton_structure:,
        converted_pages: converted_pages.map(&:to_h),
        converted_tests: converted_tests.map(&:to_h),
        converted_features: converted_features.map(&:to_h),
        converted_steps: converted_steps.map(&:to_h),
        gemfile_additions:,
        config_overrides:,
        warnings:,
        manual_actions:
      }
    end

    def to_json(*args)
      require 'json'
      to_h.to_json(*args)
    end

    def summary
      {
        pages: converted_pages.length,
        tests: converted_tests.length,
        features: converted_features.length,
        steps: converted_steps.length,
        custom_gems: gemfile_additions.length,
        warnings: warnings.length,
        manual_actions: manual_actions.length
      }
    end
  end

  ConvertedFile = Struct.new(:output_path, :content, :source_file, :conversion_notes, keyword_init: true) do
    def to_h
      {
        output_path:,
        content:,
        source_file:,
        conversion_notes:
      }
    end
  end
end
