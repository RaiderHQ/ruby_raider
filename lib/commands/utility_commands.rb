# frozen_string_literal: true

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
         type: :hash, required: false, desc: 'The options you want your browser to run with', aliases: '-o'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser(default_browser = nil)
    Utilities.new.browser = default_browser unless default_browser.nil?
    Utilities.new.browser_options = options[:opts] unless options[:opts].nil?
    Utilities.new.delete_browser_options if options[:delete]
  end

  map '-b' => 'browser'

  desc 'raid', 'It runs all the tests in a project'

  def raid
    Utilities.new.run
  end

  map '-r' => 'raid'

  desc 'config', 'Creates a new config file'
  option :path,
         type: :string, required: false, desc: 'The path where your config file will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected config file', aliases: '-d'
end
