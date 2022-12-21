# frozen_string_literal: true

require 'thor'

class Generator < Thor::Group
  include Thor::Actions

  argument :automation
  argument :framework
  argument :name
  argument :visual_automation

  def self.source_root
    "#{File.dirname(__FILE__)}/templates"
  end
end
