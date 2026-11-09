# frozen_string_literal: true

require 'json'

module RubyRaider
  module Flows
    # Reads .raider/flows/<name>/runs.jsonl, which the project's flows/support/run.rb appends to.
    class RunLog
      MAX_BYTES = 1024 * 1024
      SUMMARY = %w[status finished_at failed_step results_dir].freeze

      # [{name, file, last: {status, finished_at, failed_step, results_dir} | nil}], the shape `raider flow list --json` prints
      def self.summaries(project)
        project.flow_names.map do |name|
          last = new(project, name).last
          { 'name' => name, 'file' => "flows/#{name}_flow.rb", 'last' => last && SUMMARY.to_h { |key| [key, last[key]] } }
        end
      end

      def initialize(project, name)
        @file = project.path(".raider/flows/#{name}/runs.jsonl")
      end

      # Every readable line, oldest first; a broken line is skipped
      def lines
        return [] unless File.file?(@file) && File.size(@file) <= MAX_BYTES

        File.readlines(@file).filter_map do |line|
          parsed = JSON.parse(line)
          parsed if parsed.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end
      end

      def last = lines.last

      def find(run_id) = lines.reverse.find { |line| line['run_id'] == run_id }
    end
  end
end
