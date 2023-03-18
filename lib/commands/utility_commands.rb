# frozen_string_literal: true

require 'thor'
require_relative '../utilities/utilities'
require_relative '../utilities/open_ai'

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

  map '-p' => 'path'

  desc 'url [URL]', 'Sets the default url for a project'

  def url(default_url)
    Utilities.url = default_url
  end

  map '-u' => 'url'

  desc 'browser [BROWSER]', 'Sets the default browser for a project'
  option :opts,
         type: :array, required: false, desc: 'The options you want your browser to run with', aliases: '-o'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser(default_browser = nil)
    Utilities.browser = default_browser if default_browser
    browser_options(options[:opts]) if options[:opts] || options[:delete]
  end

  map '-b' => 'browser'

  desc 'browser_options [OPTIONS]', 'Sets the browser options for the project'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser_options(*opts)
    Utilities.browser_options = opts unless opts.empty?
    Utilities.delete_browser_options if options[:delete]
  end

  map '-bo' => 'browser_options'

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

  map '-r' => 'raid'

  desc 'config', 'Creates a new config file'
  option :path,
         type: :string, required: false, desc: 'The path where your config file will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected config file', aliases: '-d'

  desc 'platform [PLATFORM]', 'Sets the default platform for a cross-platform project'

  def platform(platform)
    Utilities.platform = platform
  end

  map '-pl' => 'platform'

  desc 'download_builds [BUILD_TYPE]', 'It downloads the example builds for appium projects'
  def download_builds(build_type)
    raise 'Please select one of the following build types: android, ios, both' unless %w[android ios both].include?(build_type)

    Utilities.download_builds build_type
  end

  map '-d' => 'download_builds'

  desc 'version', 'It shows the version of Ruby Raider you are currently using'
  def version
    spec = Gem::Specification.load('ruby_raider.gemspec')
    version = spec.version
    puts "The Ruby Raider version is #{version}, Happy testing!"
  end

  map '-v' => 'version'

  desc 'open_ai [REQUEST]', 'Uses open AI to create a file or generate output'
  option :path,
         type: :string, required: false, desc: 'The path where your file will be created', aliases: '-p'
  option :edit,
         type: :string, required: false, desc: 'Path to the file you want to edit', aliases: '-e'

  def open_ai(request, path = nil)
    path ||= options[:path]
    if options[:edit]
      pp 'Editing File...'
      OpenAi.edit_file(options[:edit], request)
      pp "File #{options[:edit]} edited"
    elsif path
      pp 'Generating File...'
      OpenAi.create_file(path, request)
      pp "File created in #{path}"
    else
      puts OpenAi.output(request)
    end
  end

  map '-oa' => 'open_ai'
end
