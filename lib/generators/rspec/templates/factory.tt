# frozen_string_literal: true

require 'yaml'

class ModelFactory
  def self.for(model)
    path = File.expand_path("models/data/#{model}.yml")
    YAML.load_file(path)
  end
end
