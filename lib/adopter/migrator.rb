# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative '../generators/invoke_generators'

module Adopter
  class Migrator
    attr_reader :plan, :results

    def initialize(plan)
      @plan = plan
      @results = { pages: 0, tests: 0, features: 0, steps: 0, errors: [] }
    end

    def execute
      generate_skeleton
      write_converted_pages
      write_converted_tests
      write_converted_features
      write_converted_steps
      merge_gemfile
      apply_config_overrides
      results
    end

    private

    # Phase A: Generate a standard Raider project skeleton
    def generate_skeleton
      InvokeGenerators.generate_framework(plan.skeleton_structure)
    end

    # Phase B: Overlay converted user files on top of the skeleton

    def write_converted_pages
      plan.converted_pages.each do |file|
        write_file(file)
        @results[:pages] += 1
      end
    end

    def write_converted_tests
      plan.converted_tests.each do |file|
        write_file(file)
        @results[:tests] += 1
      end
    end

    def write_converted_features
      plan.converted_features.each do |file|
        write_file(file)
        @results[:features] += 1
      end
    end

    def write_converted_steps
      plan.converted_steps.each do |file|
        write_file(file)
        @results[:steps] += 1
      end
    end

    def write_file(converted_file)
      FileUtils.mkdir_p(File.dirname(converted_file.output_path))
      File.write(converted_file.output_path, converted_file.content)
    rescue StandardError => e
      @results[:errors] << "Failed to write #{converted_file.output_path}: #{e.message}"
    end

    def merge_gemfile
      return if plan.gemfile_additions.empty?

      gemfile_path = "#{plan.output_path}/Gemfile"
      return unless File.exist?(gemfile_path)

      content = File.read(gemfile_path)
      additions = plan.gemfile_additions.reject { |gem| content.include?("'#{gem}'") }
      return if additions.empty?

      gem_lines = additions.map { |gem| "gem '#{gem}'" }.join("\n")
      File.write(gemfile_path, "#{content}\n# Gems from source project\n#{gem_lines}\n")
    end

    def apply_config_overrides
      return if plan.config_overrides.empty?

      config_path = "#{plan.output_path}/config/config.yml"
      return unless File.exist?(config_path)

      config = YAML.safe_load(File.read(config_path), permitted_classes: [Symbol]) || {}
      plan.config_overrides.each { |key, value| config[key.to_s] = value }
      File.write(config_path, YAML.dump(config))
    end
  end
end
