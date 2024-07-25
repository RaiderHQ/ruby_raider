# frozen_string_literal: true

require 'thor'

module RubyRaider
  class Scaffolding < Thor::Group
    include Thor::Actions

    argument :name, optional: true
    argument :path, optional: true

    def self.source_root
      "#{File.dirname(__FILE__)}/templates"
    end

    def generate_page
      template('page_object.tt', default_path("page_objects/pages/#{name}.rb", '_page.rb'))
    end

    def generate_feature
      template('feature.tt', default_path("features/#{name}.feature", '.feature'))
    end

    def generate_spec
      template('spec.tt', default_path("spec/#{name}_page_spec.rb", '_spec.rb'))
    end

    def generate_helper
      template('helper.tt', default_path("helpers/#{name}_helper.rb", '_helper.rb'))
    end

    def generate_steps
      template('steps.tt', default_path("features/step_definitions/#{name}_steps.rb", '_steps.rb'))
    end

    def generate_config
      template('../../generators/templates/common/config.tt',
               default_path('config/config.yml', '.yml'))
    end

    def delete_page
      remove_file(default_path("page_objects/pages/#{name}.rb", '_page.rb'))
    end

    def delete_feature
      remove_file(default_path("features/#{name}.feature", '.feature'))
    end

    def delete_spec
      remove_file(default_path("spec/#{name}_page_spec.rb", '_spec.rb'))
    end

    def delete_helper
      remove_file(default_path("helpers/#{name}_helper.rb", '_helper.rb'))
    end

    def delete_steps
      remove_file(default_path("features/step_definitions/#{name}_steps.rb", '_steps.rb'))
    end

    def delete_config
      remove_file(default_path('config/config.yml', '.yml'))
    end

    def default_path(standard_path, file_type)
      path ? "#{path}/#{name}#{file_type}" : standard_path
    end
  end
end
