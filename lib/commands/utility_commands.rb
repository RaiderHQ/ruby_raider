# frozen_string_literal: true

require 'thor'
require_relative '../utilities/utilities'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
module RubyRaider
  class UtilityCommands < Thor
    desc 'path [PATH]', 'Sets the default path for scaffolding'
    option :feature,
           type: :boolean, required: false, desc: 'The default path for your features', aliases: '-f'
    option :helper,
           type: :boolean, required: false, desc: 'The default path for your helpers', aliases: '-h'
    option :spec,
           type: :boolean, required: false, desc: 'The default path for your specs', aliases: '-s'

    def path(default_path)
      type = options.empty? ? 'page' : options.keys.first
      Utilities.send("#{type}_path=", default_path)
    end

    desc 'url [URL]', 'Sets the default url for a project'

    def url(default_url)
      Utilities.url = default_url
    end

    desc 'browser [BROWSER]', 'Sets the default browser for a project'
    option :opts,
           type: :array, required: false, desc: 'The options you want your browser to run with', aliases: '-o'
    option :delete,
           type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

    def browser(default_browser = nil)
      Utilities.browser = default_browser if default_browser
      selected_options = options[:opts]
      browser_options(selected_options) if selected_options || options[:delete]
    end

    desc 'browser_options [OPTIONS]', 'Sets the browser options for the project'
    option :delete,
           type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

    def browser_options(*opts)
      Utilities.browser_options = opts unless opts.empty?
      Utilities.delete_browser_options if options[:delete]
    end

    desc 'raid', 'It runs all the tests in a project'
    option :parallel,
           type: :boolean, required: false, desc: 'It runs the tests in parallel', aliases: '-p'
    option :opts,
           type: :array, required: false, desc: 'The options that your run will run with', aliases: '-o'

    def raid
      selected_options = options[:opts]
      if options[:parallel]
        Utilities.parallel_run(selected_options)
      else
        Utilities.run(selected_options)
      end
    end

    desc 'config', 'Creates a new config file'
    option :path,
           type: :string, required: false, desc: 'The path where your config file will be created', aliases: '-p'
    option :delete,
           type: :boolean, required: false, desc: 'This will delete the selected config file', aliases: '-d'

    desc 'platform [PLATFORM]', 'Sets the default platform for a cross-platform project'

    def platform(platform)
      Utilities.platform = platform
    end

    desc 'start_appium', 'It starts the appium server'

    def start_appium
      system 'appium  --base-path /wd/hub'
    end
  end
end
