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
  def page(name)
    Scaffolding.new([name, load_config_path]).generate_class
  end

  desc "feature [FEATURE_NAME]", "Creates a new feature"
  def feature(name)
    Scaffolding.new([name, load_config_path]).generate_feature
  end

  desc "spec [SPEC_NAME]", "Creates a new spec"
  def spec(name)
    Scaffolding.new([name, load_config_path]).generate_spec
  end

  desc "path [PATH]", "Sets the default path for scaffolding"
  def path(default_path)
    Utilities.new.path = default_path
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
    def load_config_path
      YAML.load_file('config/config.yml')['path']
    end
  end
end