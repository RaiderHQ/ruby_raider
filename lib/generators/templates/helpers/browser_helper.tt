# frozen_string_literal: true

require 'yaml'
require 'watir'

module BrowserHelper

  def browser(*args)
    @browser ||= create_browser(*args)
  end

  private

  def config
    @config ||= YAML.load_file('config/config.yml')
  end

  def create_browser(*args)
    args = args.empty? ? config['browser_arguments'][config['browser']] : args
    Watir::Browser.new(config['browser'], options: { args: args })
  end
end
