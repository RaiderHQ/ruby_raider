# frozen_string_literal: true

require 'thor'
require 'yaml'
require_relative 'name_normalizer'
require_relative 'project_detector'
require_relative '../generators/invoke_generators'

class Scaffolding < Thor::Group
  include Thor::Actions

  argument :name, optional: true
  argument :path, optional: true

  def self.source_root
    "#{File.dirname(__FILE__)}/templates"
  end

  # --- Generation methods ---

  def generate_page
    refuse_watir
    template('page_object.tt', default_path("page_objects/pages/#{normalized_name}.rb", '_page.rb'))
  end

  def generate_feature
    refuse_watir
    template('feature.tt', default_path("features/#{normalized_name}.feature", '.feature'))
  end

  def generate_spec
    refuse_watir
    template('spec.tt', default_path("spec/#{normalized_name}_page_spec.rb", '_spec.rb'))
  end

  def generate_helper
    refuse_watir
    template('helper.tt', default_path("helpers/#{normalized_name}_helper.rb", '_helper.rb'))
  end

  def generate_steps
    refuse_watir
    template('steps.tt', default_path("features/step_definitions/#{normalized_name}_steps.rb", '_steps.rb'))
  end

  def generate_component
    refuse_watir
    template('component.tt', default_path("page_objects/components/#{normalized_name}.rb", '.rb'))
  end

  def generate_config
    refuse_watir
    template('../../generators/templates/common/config.tt',
             default_path('config/config.yml', '.yml'))
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

  def watir?
    automation_type == 'watir'
  end

  no_commands do
    def refuse_watir
      raise Thor::Error, InvokeGenerators::WATIR_REMOVED if watir?
    end
  end

  def wait_helper?
    ScaffoldProjectDetector.wait_helper?
  end

  def default_path(standard_path, file_type)
    path ? "#{path}/#{normalized_name}#{file_type}" : standard_path
  end
end
