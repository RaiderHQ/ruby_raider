# frozen_string_literal: true

require_relative '../schedules/run_log'
require_relative '../schedules/kind'

module RubyRaider
  module Flows
    # Reads .raider/flows/<name>/runs.jsonl, which the project's flows/support/run.rb appends to
    # (Schedules::RunLog in the flow folder).
    class RunLog < Schedules::RunLog
      SUMMARY = %w[status finished_at failed_step results_dir].freeze

      # [{name, file, last: {status, finished_at, failed_step, results_dir} | nil}], the shape `raider flow list --json` prints
      def self.summaries(project)
        project.flow_names.map do |name|
          last = new(project, name).last_result
          { 'name' => name, 'file' => "flows/#{name}_flow.rb", 'last' => last && SUMMARY.to_h { |key| [key, last[key]] } }
        end
      end

      def initialize(project, name)
        super(project, name, dir: Schedules::Kind::FLOW_LEGACY.dir)
      end
    end
  end
end
