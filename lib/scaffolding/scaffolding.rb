# frozen_string_literal: true

require 'thor'

class Scaffolding < Thor::Group
  include Thor::Actions

  argument :name, optional: true
  argument :path, optional: true

  def self.source_root
    "#{File.dirname(__FILE__)}/templates"
  end

  def generate_class
    template('page_object.tt', default_path("page_objects/pages/#{name}_page.rb", '_page.rb'))
  end

  def generate_feature
    template('feature.tt', default_path("features/#{name}.feature", '.feature'))
  end

  def generate_spec
    template('spec.tt', default_path("spec/#{name}_spec.rb", '_spec.rb'))
  end

  def generate_helper
    template('helper.tt', default_path("helpers/#{name}_helper.rb", '_helper.rb'))
  end

  def generate_config
    template('../../generators/templates/common/config.tt',
             default_path('config/config.yml', '.yml'))
  end

  def delete_class
    remove_file(default_path("page_objects/pages/#{name}_page.rb", '_page.rb'))
  end

  def delete_feature
    remove_file(default_path("features/#{name}.feature", '.feature'))
  end

  def delete_spec
    remove_file(default_path("spec/#{name}_spec.rb", '_spec.rb'))
  end

  def delete_helper
    remove_file(default_path("helpers/#{name}_helper.rb", '_helper.rb'))
  end

  def delete_config
    remove_file(default_path('config/config.yml', '.yml'))
  end

  def default_path(standard_path, file_type)
    path ? standard_path : "#{path}/#{name}#{file_type}"
  end
end
