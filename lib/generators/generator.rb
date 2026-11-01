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
       #{base_path}/rspec/templates
       #{base_path}/templates #{base_path}/infrastructure/templates ]
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

  # Only the options after automation, framework and name, so a project named "azure" is not Azure CI
  def azure?
    args.drop(3).include?('azure')
  end

  def github_ci?
    !azure?
  end

  def selenium?
    args.include?('selenium')
  end

  def watir?
    args.include?('watir')
  end

  # Selenium and Appium projects get the auto-waiting WaitHelper; Watir keeps its own waits
  def wait_helper?
    !watir?
  end

  # False for `raider new -p examples:false`: an empty skeleton without the example pages, tests and wiring
  def examples?
    !args.include?('no_examples')
  end

  def web?
    (args & %w[selenium watir]).count.positive?
  end

  def axe_addon?
    args.include?('axe_addon')
  end

  def selenium_based?
    args.include?('selenium')
  end

  def ruby_raider_version_requirement
    major, minor = File.read(File.expand_path('../version', __dir__)).strip.split('.')
    "~> #{major}.#{minor}"
  end

  private

  def _initializer
    @_initializer ||= super
  end

  alias initializer _initializer
end
