# frozen_string_literal: true

require 'tty-prompt'
require_relative 'project_detector'

# :reek:TooManyMethods { enabled: false }
class ScaffoldMenu
  COMPONENTS = {
    'Page object' => :page,
    'Spec (RSpec)' => :spec,
    'Feature (Cucumber)' => :feature,
    'Steps (Cucumber)' => :steps,
    'Helper' => :helper,
    'Component' => :component,
    'Model data' => :model
  }.freeze

  def initialize
    @prompt = TTY::Prompt.new
  end

  def run
    names = ask_names
    components = ask_components
    uses = ask_relationships
    preview_and_confirm(names, components, uses)
  end

  # Programmatic entry point for raider_desktop
  def self.build_options(names:, components:, uses: [])
    { names: Array(names), components: Array(components), uses: Array(uses) }
  end

  private

  def ask_names
    input = @prompt.ask('Enter scaffold name(s), comma-separated:') do |q|
      q.required true
    end
    input.split(',').map(&:strip).reject(&:empty?)
  end

  def ask_components
    project = ScaffoldProjectDetector.detect
    defaults = default_components(project)

    @prompt.multi_select('Select components to generate:', default: defaults) do |menu|
      COMPONENTS.each do |label, value|
        menu.choice label, value
      end
    end
  end

  def ask_relationships
    return [] unless @prompt.yes?('Add page dependencies (--uses)?', default: false)

    pages = Dir.glob('page_objects/pages/*.rb').map { |f| File.basename(f, '.rb') }
    return [] if pages.empty?

    @prompt.multi_select('Select dependent pages:', pages)
  end

  def preview_and_confirm(names, components, uses)
    files = planned_files(names, components)

    @prompt.say("\nWill create:")
    files.each { |f| @prompt.say("  #{f}") }
    @prompt.say('')

    return nil unless @prompt.yes?('Proceed?')

    { names:, components:, uses: }
  end

  def planned_files(names, components)
    names.flat_map do |name|
      components.map { |comp| file_for(name, comp) }
    end
  end

  def file_for(name, component)
    case component
    when :page then "page_objects/pages/#{name}.rb"
    when :spec then "spec/#{name}_page_spec.rb"
    when :feature then "features/#{name}.feature"
    when :steps then "features/step_definitions/#{name}_steps.rb"
    when :helper then "helpers/#{name}_helper.rb"
    when :component then "page_objects/components/#{name}.rb"
    when :model then "models/data/#{name}.yml"
    end
  end

  def default_components(project)
    defaults = [:page]
    if project[:has_features]
      defaults += %i[feature steps]
    elsif project[:has_test]
      defaults << :spec
    else
      defaults << :spec
    end
    defaults.map { |d| COMPONENTS.key(d) }.compact
  end
end
