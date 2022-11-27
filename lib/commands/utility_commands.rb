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
    Utilities.new.send("#{type}_path=", default_path)
  end

  map '-p' => 'path'

  desc 'url [URL]', 'Sets the default url for a project'

  def url(default_url)
    Utilities.new.url = default_url
  end

  map '-u' => 'url'

  desc 'browser [BROWSER]', 'Sets the default browser for a project'
  option :opts,
         type: :array, required: false, desc: 'The options you want your browser to run with', aliases: '-o'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser(default_browser = nil)
    Utilities.new.browser = default_browser if default_browser
    browser_options(options[:opts]) if options[:opts] || options[:delete]
  end

  map '-b' => 'browser'

  desc 'browser_options [OPTIONS]', 'Sets the browser options for the project'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser_options(*opts)
    Utilities.new.browser_options = opts unless opts.empty?
    Utilities.new.delete_browser_options if options[:delete]
  end

  map '-bo' => 'browser_options'

  desc 'raid [OPTS]', 'It runs all the tests in a project'
  option :parallel,
         type: :boolean, required: false, desc: 'It runs the tests in parallel', aliases: '-p'
  option :opts,
         type: :array, required: false, desc: 'The options that your run will run with', aliases: '-o'

  def raid
    if options[:parallel]
      Utilities.new.parallel_run(options[:opts])
    else
      Utilities.new.run(options[:opts])
    end
  end

  map '-r' => 'raid'

  desc 'config', 'Creates a new config file'
  option :path,
         type: :string, required: false, desc: 'The path where your config file will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected config file', aliases: '-d'

  desc 'platform [platform]', 'Sets the default platform for a cross-platform project'

  def platform(platform)
    Utilities.new.platform = platform
  end

  map '-pl' => 'platform'
end
