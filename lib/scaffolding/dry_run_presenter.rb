# frozen_string_literal: true

module DryRunPresenter
  module_function

  def preview(planned_files)
    return [] if planned_files.empty?

    puts '[dry-run] Would create:'
    planned_files.each do |file|
      puts "  #{file}"
    end
    puts ''
    planned_files
  end
end
