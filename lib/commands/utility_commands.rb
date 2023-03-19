# frozen_string_literal: true

require 'thor'
require_relative '../utilities/utilities'

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
    browser_options(options[:opts]) if options[:opts] || options[:delete]
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
    if options[:parallel]
      Utilities.parallel_run(options[:opts])
    else
      Utilities.run(options[:opts])
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

  desc 'builds [BUILD_TYPE]', 'It downloads the example builds for appium projects'
  def builds(build_type)
    raise 'Please select one of the following build types: android, ios, both' unless %w[android ios both].include?(build_type)

    Utilities.download_builds build_type
  end
end
