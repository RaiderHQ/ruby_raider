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

  def cucumber?
    args.include?('cucumber')
  end

  # The framework is cross platform when it supports Android and iOS
  def cross_platform?
    args.include?('cross_platform')
  end

  def mobile?
    (args & %w[android ios cross_platform sparkling_ios]).count.positive?
  end

  def single_platform?
    (args & %w[android ios sparkling_ios]).count.positive?
  end

  def rspec?
    args.include?('rspec')
  end

  def selenium?
    args.include?('selenium')
  end

  def visual?
    initializer.first.last
  end

  def watir?
    args.include?('watir')
  end

  def web?
    args.include?(%w[selenium watir])
  end

  private

  def _initializer
    @_initializer ||= super
  end
  alias initializer _initializer
end
