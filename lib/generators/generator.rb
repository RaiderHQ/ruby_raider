# frozen_string_literal: true

require 'thor'
require_relative 'template_renderer'

class Generator < Thor::Group
  include Thor::Actions
  include TemplateRenderer

  LATEST_RUBY = '3.4'

  argument :automation
  argument :framework
  argument :name

  def self.source_paths
    base_path = File.dirname(__FILE__)
    %W[#{base_path}/automation/templates #{base_path}/cucumber/templates
       #{base_path}/rspec/templates #{base_path}/minitest/templates
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

  def minitest?
    args.include?('minitest')
  end

  def selenium?
    args.include?('selenium')
  end

  def capybara?
    args.include?('capybara')
  end

  def visual_addon?
    args.include?('visual_addon')
  end

  def watir?
    args.include?('watir')
  end

  def web?
    (args & %w[selenium watir capybara]).count.positive?
  end

  def axe_addon?
    args.include?('axe_addon')
  end

  def lighthouse_addon?
    args.include?('lighthouse_addon')
  end

  def selenium_based?
    args.include?('selenium')
  end

  def skip_allure?
    args.include?('skip_allure')
  end

  def skip_video?
    args.include?('skip_video')
  end

  def allure_reporter?
    has_reporter = args.any? { |a| a&.start_with?('reporter_') }
    has_reporter ? args.include?('reporter_allure') : !skip_allure?
  end

  def junit_reporter?
    args.include?('reporter_junit')
  end

  def json_reporter?
    args.include?('reporter_json')
  end

  def ruby_version
    arg = args.find { |a| a&.start_with?('ruby_version:') }
    arg ? arg.split(':', 2).last : LATEST_RUBY
  end

  private

  def _initializer
    @_initializer ||= super
  end

  alias initializer _initializer
end
