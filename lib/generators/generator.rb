# frozen_string_literal: true

require 'thor'

class Generator < Thor::Group
  include Thor::Actions

  argument :automation
  argument :framework
  argument :name
  argument :visual_automation, optional: true

  def self.source_paths
    base_path = File.dirname(__FILE__)
    %W[#{base_path}/automation/templates #{base_path}/cucumber/templates #{base_path}/rspec/templates #{base_path}/templates]
  end

  def args
    initializer.first
  end

  def visual_selected?
    initializer.first.last
  end

  def mobile_platform?
    (args & %w[android ios cross_platform]).empty?
  end

  private

  def _initializer
    @_initializer ||= super
  end
  alias initializer _initializer
end
