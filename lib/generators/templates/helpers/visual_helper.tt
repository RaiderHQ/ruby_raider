# frozen_string_literal: true

require 'active_support/inflector'
require 'eyes_selenium'
require 'yaml'

module VisualHelper
    attr_reader :eyes

    SELENIUM = Applitools::Selenium
    VISUAL_GRID = SELENIUM::VisualGridRunner
    EYES = SELENIUM::Eyes
    TARGET = SELENIUM::Target
    BATCHINFO = Applitools::BatchInfo
    REGTANGLE_SIZE = Applitools::RectangleSize

    def create_grid_runner(concurrency = 1)
      VISUAL_GRID.new(concurrency)
    end

    def create_eyes(grid_runner)
      EYES.new(runner: grid_runner)
    end

    def check_page(page)
      page = format_page(page)
      @eyes.check(page, TARGET.window.fully)
    end

    def configure_eyes(eyes, options = nil)
      options ||= YAML.load_file('config/options.yml')

      eyes.configure do |conf|
        #  You can get your api key from the Applitools dashboard
        general_config(options, conf)
        add_browsers(options[:browsers], conf)
        add_devices(options[:devices], conf)
      end
    end

    def format_page(page)
      page.instance_of?(String) ? page : page.to_s
    end

    def add_browsers(browsers, conf)
      browsers.each do |browser|
        conf.add_browser(browser[:height], browser[:width], "BrowserType::#{browser[:name].upcase}".constantize)
      end
    end

    def add_devices(devices, conf)
      devices.each do |device|
        conf.add_device_emulation("Devices::#{device[:name]}".constantize,
                                  "Orientation::#{device[:orientation]}".constantize)
      end
    end

    def general_config(options, conf)
      conf.api_key = ENV['APPLITOOLS_API_KEY']
      conf.batch = BATCHINFO.new(options[:batch_name])
      conf.app_name = options[:app_name]
      conf.test_name = options[:test_name]
      conf.viewport_size = REGTANGLE_SIZE.new(options[:viewport_size][:height], options[:viewport_size][:width])
    end
end
