# frozen_string_literal: true

require 'thor'

class Generator < Thor::Group
  include Thor::Actions

  argument :automation
  argument :framework
  argument :name
  argument :visual_automation, optional: true

  def self.source_paths
    %W[#{File.dirname(__FILE__)}/automation/templates #{File.dirname(__FILE__)}/cucumber/templates #{File.dirname(__FILE__)}/rspec/templates #{File.dirname(__FILE__)}/templates]
  end
end
