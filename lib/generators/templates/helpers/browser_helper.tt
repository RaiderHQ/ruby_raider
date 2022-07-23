# frozen_string_literal: true

require 'yaml'
require 'selenium-webdriver'
require 'watir'
require 'webdrivers'

module Raider
  module BrowserHelper
      attr_reader :browser

      def new_browser(*args)
        @config = YAML.load_file('config/config.yml')
        browser = @config['browser'].to_sym
        args = args.empty? ? @config['browser_options'] : args
        @browser = Watir::Browser.new(browser, options: { args: args })
      end
  end
end