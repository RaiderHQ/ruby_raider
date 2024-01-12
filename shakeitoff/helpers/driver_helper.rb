# frozen_string_literal: true
require 'yaml'
require 'active_support/inflector'
require 'selenium-webdriver'

module DriverHelper
    def driver(*opts)
    @driver ||= create_driver(*opts)
  end
  
  private

  def create_driver(*opts)
    @config = YAML.load_file('config/config.yml')
    browser = @config['browser'].to_sym
    Selenium::WebDriver.for(browser, options: create_webdriver_options(*opts))
  end

  def browser_arguments(*opts)
    opts.empty? ? @config['browser_arguments'][@config['browser']] : opts
  end

  def driver_options
    @config['driver_options']
  end

  # :reek:FeatureEnvy
  def create_webdriver_options(*opts)
    load_browser = @config['browser'].to_s
    browser = load_browser == 'ie' ? load_browser.upcase : load_browser.capitalize
    options = "Selenium::WebDriver::#{browser}::Options".constantize.new
    browser_arguments(*opts).each { |arg| options.add_argument(arg) }
    driver_options.each { |opt| options.add_option(opt.first, opt.last) }
    options
  end

end
