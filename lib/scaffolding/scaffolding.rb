require 'thor'

class Scaffolding < Thor::Group
  include Thor::Actions

  argument :name
  argument :path, optional: true

  def self.source_root
    File.dirname(__FILE__) + '/templates'
  end

  def generate_class
    template('page_object.tt', default_path("page_objects/pages/#{name}_page.rb") )
  end

  def generate_feature
    template('feature.tt', default_path("features/#{name}.feature"))
  end

  def generate_spec
    template('spec.tt', default_path("./spec/#{name}_page.rb"))
  end

  def default_path(standard_path)
    path.nil? ? standard_path : "#{path}/#{name}"
  end
end
