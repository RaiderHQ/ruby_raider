require 'thor'
require 'yaml'
require_relative 'generators/menu_generator'
require_relative '../lib/scaffolding/scaffolding'
require_relative '../lib/utilities/utilities'

class RubyRaider < Thor
  desc "new [PROJECT_NAME]", "Creates a new framework based on settings picked"

  def new(project_name)
    MenuGenerator.generate_choice_menu(project_name)
  end

  desc "page [PAGE_NAME]", "Creates a new page object"
  option :path,
         :type => :string, :required => false, :desc => 'The path where your page will be created', :aliases => '-p'
  option :delete,
         :type => :boolean, :required => false, :desc => 'This will delete the selected page', :aliases => '-d'

  def page(name)
    path = options[:path].nil? ? load_config_path('page') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_class
    else
      Scaffolding.new([name, path]).generate_class
    end
  end

  desc "feature [FEATURE_NAME]", "Creates a new feature"
  option :path,
         :type => :string, :required => false, :desc => 'The path where your feature will be created', :aliases => '-p'
  option :delete,
         :type => :boolean, :required => false, :desc => 'This will delete the selected feature', :aliases => '-d'

  def feature(name)
    path = options[:path].nil? ? load_config_path('feature') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_feature
    else
      Scaffolding.new([name, path]).generate_feature
    end
  end

  desc "spec [SPEC_NAME]", "Creates a new spec"
  option :path,
         :type => :string, :required => false, :desc => 'The path where your spec will be created', :aliases => '-p'
  option :delete,
         :type => :boolean, :required => false, :desc => 'This will delete the selected spec', :aliases => '-d'

  def spec(name)
    path = options[:path].nil? ? load_config_path('spec') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_spec
    else
      Scaffolding.new([name, path]).generate_spec
    end
  end

  desc "helper [HELPER_NAME]", "Creates a new helper"
  option :path,
         :type => :string, :required => false, :desc => 'The path where your helper will be created', :aliases => '-p'
  option :delete,
         :type => :boolean, :required => false, :desc => 'This will delete the selected helper', :aliases => '-d'

  def helper(name)
    path = options[:path].nil? ? load_config_path('helper') : options[:path]
    if options[:delete]
      Scaffolding.new([name, path]).delete_helper
    else
      Scaffolding.new([name, path]).generate_helper
    end
  end

  desc "path [PATH]", "Sets the default path for scaffolding"
  option :feature,
         :type => :boolean, :required => false, :desc => 'The default path for your features', :aliases => '-f'
  option :helper,
         :type => :boolean, :required => false, :desc => 'The default path for your helpers', :aliases => '-h'
  option :spec,
         :type => :boolean, :required => false, :desc => 'The default path for your specs', :aliases => '-s'
  def path(default_path)
    type = options.empty? ? 'page' : options.keys.first
    Utilities.new.send("#{type}_path=", default_path)
  end

  desc "url [URL]", "Sets the default url for a project"

  def url(default_url)
    Utilities.new.url = default_url
  end

  desc "browser [BROWSER]", "Sets the default browser for a project"

  def browser(default_browser)
    Utilities.new.browser = default_browser
  end

  desc "raid", "It runs all the tests in a project"

  def raid
    Utilities.new.run
  end

  no_commands do
    def load_config_path(type)
      YAML.load_file('config/config.yml')["#{type}_path"] unless YAML.load_file('config/config.yml').nil?
    end
  end
end
