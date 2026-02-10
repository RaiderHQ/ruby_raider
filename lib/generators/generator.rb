# frozen_string_literal: true

require 'thor'
require_relative 'template_renderer'

class Generator < Thor::Group
  include Thor::Actions
  include TemplateRenderer

  argument :automation
  argument :framework
  argument :name

  def self.source_paths
    base_path = File.dirname(__FILE__)
    %W[#{base_path}/automation/templates #{base_path}/cucumber/templates
       #{base_path}/rspec/templates #{base_path}/templates #{base_path}/infrastructure/templates ]
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
    (args & %w[android ios cross_platform]).count.positive?
  end

  def single_platform?
    (args & %w[android ios]).count.positive?
  end

  def ios?
    args.include?('ios')
  end

  def android?
    args.include?('android')
  end

  def rspec?
    args.include?('rspec')
  end

  def selenium?
    args.include?('selenium')
  end

  def visual?
    args.include?('applitools')
  end

  def watir?
    args.include?('watir')
  end

  def web?
    (args & (%w[selenium watir axe applitools])).count.positive?
  end

  def axe?
    args.include?('axe')
  end

  def selenium_based?
    (args & %w[selenium axe applitools]).count.positive?
  end

  private

  def _initializer
    @_initializer ||= super
  end

  alias initializer _initializer
end
