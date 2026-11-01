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
    framework == 'cucumber'
  end

  # The framework is cross platform when it supports Android and iOS
  def cross_platform?
    automation == 'cross_platform'
  end

  def mobile?
    %w[android ios cross_platform].include?(automation)
  end

  def single_platform?
    %w[android ios].include?(automation)
  end

  def ios?
    automation == 'ios'
  end

  def android?
    automation == 'android'
  end

  def rspec?
    framework == 'rspec'
  end

  def azure?
    options_after_name.include?('azure')
  end

  def github_ci?
    !azure?
  end

  # The automation arg only, so a project named "watir" or "selenium" keeps its own automation
  def selenium?
    automation == 'selenium'
  end

  def watir?
    automation == 'watir'
  end

  # Selenium and Appium projects get the auto-waiting WaitHelper; Watir keeps its own waits
  def wait_helper?
    !watir?
  end

  # False for `raider new -p examples:false`: an empty skeleton without the example pages, tests and wiring
  def examples?
    !options_after_name.include?('no_examples')
  end

  def web?
    selenium? || watir?
  end

  def axe_addon?
    options_after_name.include?('axe_addon')
  end

  def selenium_based?
    selenium?
  end

  def ruby_raider_version_requirement
    major, minor = File.read(File.expand_path('../version', __dir__)).strip.split('.')
    "~> #{major}.#{minor}"
  end

  private

  # Option flags only: everything after automation, framework and name
  def options_after_name
    args.drop(3)
  end

  def _initializer
    @_initializer ||= super
  end

  alias initializer _initializer
end
