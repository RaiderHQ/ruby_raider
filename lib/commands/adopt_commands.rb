# frozen_string_literal: true

require 'thor'
require_relative '../adopter/adopt_menu'

class AdoptCommands < Thor
  desc 'project [SOURCE_PATH]', 'Adopts an existing test project into Ruby Raider conventions'
  option :parameters,
         type: :hash, required: false,
         desc: 'Parameters to bypass the menu (output_path, target_automation, target_framework, ci_platform)',
         aliases: 'p'

  def project(source_path)
    params = options[:parameters]
    if params
      parsed = params.transform_keys(&:to_sym)
      parsed[:source_path] = source_path
      result = Adopter::AdoptMenu.adopt(parsed)
      print_programmatic_results(result)
    else
      Adopter::AdoptMenu.new.run
    end
  rescue Adopter::MobileProjectError => e
    puts "Error: #{e.message}"
    exit 1
  rescue ArgumentError => e
    puts "Invalid parameters: #{e.message}"
    exit 1
  end

  private

  def print_programmatic_results(result)
    plan = result[:plan]
    results = result[:results]
    puts "Adoption complete: #{results[:pages]} pages, #{results[:tests]} tests, " \
         "#{results[:features]} features, #{results[:steps]} steps"
    puts "Warnings: #{plan.warnings.join('; ')}" unless plan.warnings.empty?
    puts "Errors: #{results[:errors].join('; ')}" unless results[:errors].empty?
    puts "Output: #{plan.output_path}"
  end
end
