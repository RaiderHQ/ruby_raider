# frozen_string_literal: true

require 'thor'
require 'yaml'
require_relative 'name_normalizer'
require_relative 'project_detector'

class Scaffolding < Thor::Group
  include Thor::Actions

  argument :name, optional: true
  argument :path, optional: true

  attr_writer :uses

  OVERRIDE_DIR = '.ruby_raider/templates'

  def self.source_root
    "#{File.dirname(__FILE__)}/templates"
  end

  # Check for user template override before using default
  def template(source, *args, &block)
    override = File.join(OVERRIDE_DIR, File.basename(source))
    if File.exist?(override)
      super(File.expand_path(override), *args, &block)
    else
      super
    end
  end

  # --- Generation methods ---

  def generate_page
    template('page_object.tt', default_path("page_objects/pages/#{normalized_name}.rb", '_page.rb'))
  end

  def generate_feature
    template('feature.tt', default_path("features/#{normalized_name}.feature", '.feature'))
  end

  def generate_spec
    template('spec.tt', default_path("spec/#{normalized_name}_page_spec.rb", '_spec.rb'))
  end

  def generate_helper
    template('helper.tt', default_path("helpers/#{normalized_name}_helper.rb", '_helper.rb'))
  end

  def generate_steps
    template('steps.tt', default_path("features/step_definitions/#{normalized_name}_steps.rb", '_steps.rb'))
  end

  def generate_component
    template('component.tt', default_path("page_objects/components/#{normalized_name}.rb", '.rb'))
  end

  def generate_config
    template('../../generators/templates/common/config.tt',
             default_path('config/config.yml', '.yml'))
  end

  def generate_spec_from_page(source_file, ai: false) # rubocop:disable Naming/MethodParameterName
    require_relative 'page_introspector'
    @introspected = PageIntrospector.new(source_file)
    enrich_with_ai_scenarios if ai
    template('spec_from_page.tt', "spec/#{normalized_name}_spec.rb")
  end

  def generate_page_from_url(analysis)
    @url_data = analysis
    template('page_from_url.tt', "page_objects/pages/#{normalized_name}.rb")
  end

  def generate_spec_from_url(analysis)
    @url_data = analysis
    template('spec_from_url.tt', "spec/#{normalized_name}_spec.rb")
  end

  # --- Deletion methods ---

  def delete_page
    remove_file(default_path("page_objects/pages/#{normalized_name}.rb", '_page.rb'))
  end

  def delete_feature
    remove_file(default_path("features/#{normalized_name}.feature", '.feature'))
  end

  def delete_spec
    remove_file(default_path("spec/#{normalized_name}_page_spec.rb", '_spec.rb'))
  end

  def delete_helper
    remove_file(default_path("helpers/#{normalized_name}_helper.rb", '_helper.rb'))
  end

  def delete_steps
    remove_file(default_path("features/step_definitions/#{normalized_name}_steps.rb", '_steps.rb'))
  end

  def delete_component
    remove_file(default_path("page_objects/components/#{normalized_name}.rb", '.rb'))
  end

  def delete_config
    remove_file(default_path('config/config.yml', '.yml'))
  end

  # --- Path planning (for dry-run) ---

  def self.planned_path(name, type, custom_path = nil)
    n = NameNormalizer.normalize(name)
    case type.to_s
    when 'page' then custom_path ? "#{custom_path}/#{n}_page.rb" : "page_objects/pages/#{n}.rb"
    when 'spec' then custom_path ? "#{custom_path}/#{n}_spec.rb" : "spec/#{n}_page_spec.rb"
    when 'feature' then custom_path ? "#{custom_path}/#{n}.feature" : "features/#{n}.feature"
    when 'steps' then custom_path ? "#{custom_path}/#{n}_steps.rb" : "features/step_definitions/#{n}_steps.rb"
    when 'helper' then custom_path ? "#{custom_path}/#{n}_helper.rb" : "helpers/#{n}_helper.rb"
    when 'component' then custom_path ? "#{custom_path}/#{n}.rb" : "page_objects/components/#{n}.rb"
    when 'model' then "models/data/#{n}.yml"
    end
  end

  # --- Template helpers (available in .tt files) ---

  def class_name
    NameNormalizer.to_class_name(name)
  end

  def page_class_name
    NameNormalizer.to_page_class(name)
  end

  def normalized_name
    NameNormalizer.normalize(name)
  end

  def nested?
    NameNormalizer.nested?(name)
  end

  def module_parts
    NameNormalizer.module_parts(name)
  end

  def leaf_name
    NameNormalizer.leaf_name(name)
  end

  def automation_type
    ScaffoldProjectDetector.detect_automation
  end

  def framework_type
    ScaffoldProjectDetector.detect_framework
  end

  def project_config
    ScaffoldProjectDetector.config
  end

  def selenium?
    automation_type == 'selenium'
  end

  def capybara?
    automation_type == 'capybara'
  end

  def watir?
    automation_type == 'watir'
  end

  def uses_list
    Array(@uses).reject(&:empty?)
  end

  attr_reader :introspected, :url_data

  def ai_scenarios
    @ai_scenarios || {}
  end

  def default_path(standard_path, file_type)
    path ? "#{path}/#{normalized_name}#{file_type}" : standard_path
  end

  private

  def enrich_with_ai_scenarios
    require_relative '../llm/client'
    require_relative '../llm/prompts'
    require_relative '../llm/response_parser'

    return unless Llm::Client.available?

    response = Llm::Client.complete(
      Llm::Prompts.generate_test_scenarios(
        @introspected.class_name,
        @introspected.methods,
        automation_type,
        framework_type
      ),
      system_prompt: Llm::Prompts.system_prompt
    )
    scenarios = Llm::ResponseParser.extract_scenarios(response)
    return unless scenarios

    @ai_scenarios = scenarios.each_with_object({}) do |s, hash|
      hash[s[:method]] = s
    end
  end
end
