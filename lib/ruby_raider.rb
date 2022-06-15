# frozen_string_literal: true

require 'thor'
require 'yaml'
require_relative 'generators/menu_generator'
require_relative '../lib/scaffolding/scaffolding'
require_relative '../lib/utilities/utilities'

class RubyRaider < Thor
  desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'

  def new(project_name)
    MenuGenerator.generate_choice_menu(project_name)
  end
  map '-n' => "new"

  desc 'page [PAGE_NAME]', 'Creates a new page object'
  option :path,
         type: :string, required: false, desc: 'The path where your page will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected page', aliases: '-d'

  def page(name)
    path = options[:path].nil? ? load_config_path('page') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_class
    else
      Scaffolding.new([name, path]).generate_class
    end
  end
  map '-pg' => "page"

  desc 'feature [FEATURE_NAME]', 'Creates a new feature'
  option :path,
         type: :string, required: false, desc: 'The path where your feature will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected feature', aliases: '-d'

  def feature(name)
    path = options[:path].nil? ? load_config_path('feature') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_feature
    else
      Scaffolding.new([name, path]).generate_feature
    end
  end
  map '-f' => "feature"

  desc 'spec [SPEC_NAME]', 'Creates a new spec'
  option :path,
         type: :string, required: false, desc: 'The path where your spec will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected spec', aliases: '-d'

  def spec(name)
    path = options[:path].nil? ? load_config_path('spec') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_spec
    else
      Scaffolding.new([name, path]).generate_spec
    end
  end
  map '-s' => "spec"

  desc 'helper [HELPER_NAME]', 'Creates a new helper'
  option :path,
         type: :string, required: false, desc: 'The path where your helper will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected helper', aliases: '-d'

  def helper(name)
    path = options[:path].nil? ? load_config_path('helper') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_helper
    else
      Scaffolding.new([name, path]).generate_helper
    end
  end
  map '-h' => "helper"

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
  map '-p' => "path"

  desc 'url [URL]', 'Sets the default url for a project'

  def url(default_url)
    Utilities.new.url = default_url
  end
  map '-u' => "url"

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
  map '-b' => "browser"

  desc 'raid', 'It runs all the tests in a project'
  def raid
    Utilities.new.run
  end
  map '-r' => "raid"

  desc 'scaffold [SCAFFOLD_NAME]', 'It generates everything needed to start automating'
  def scaffold(name)
    if Pathname.new('spec').exist? && !Pathname.new('features').exist?
      Scaffolding.new([name, load_config_path('spec')]).generate_spec
      Scaffolding.new([name, load_config_path('page')]).generate_class
    elsif Pathname.new('features').exist?
      Scaffolding.new([name, load_config_path('feature')]).generate_feature
      Scaffolding.new([name, load_config_path('page')]).generate_class
    else
      raise 'No features or spec folders where found. We are not sure which type of project you are running'
    end
  end
  map '-sf' => "scaffold"

  desc 'config', 'Creates a new config file'
  option :path,
         type: :string, required: false, desc: 'The path where your config file will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected config file', aliases: '-d'
  def config
    if options[:delete]
      Scaffolding.new.delete_config
    else
      Scaffolding.new.generate_config
    end
  end
  map '-c' => "config"

  no_commands do
    def load_config_path(type)
      YAML.load_file('config/config.yml')["#{type}_path"] unless YAML.load_file('config/config.yml').nil?
    end
  end
end
