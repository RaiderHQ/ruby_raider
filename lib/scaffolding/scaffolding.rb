require 'thor'

class Scaffolding < Thor::Group
  include Thor::Actions

  argument :name

  def self.source_root
    File.dirname(__FILE__) + '/templates'
  end

  def generate_class
    template('page_object.tt', "page_objects/pages/#{name}_page.rb")
  end

  def generate_feature
    template('feature.tt', "features/#{name}.feature")
  end

  def generate_spec
    template('spec.tt', "./spec/#{name}_page.rb")
  end
end
