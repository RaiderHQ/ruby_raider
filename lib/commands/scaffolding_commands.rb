# frozen_string_literal: true

require 'thor'
require_relative '../generators/menu_generator'
require_relative '../scaffolding/scaffolding'
require_relative '../commands/utility_commands'

class ScaffoldingCommands < Thor
  desc 'page [PAGE_NAME]', 'Creates a new page object'
  option :path,
         type: :string, required: false, desc: 'The path where your page will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected page', aliases: '-d'

  def page(name)
    path = options[:path] || load_config_path('page')
    if options[:delete]
      Scaffolding.new([name, path]).delete_class
    else
      Scaffolding.new([name, path]).generate_class
    end
  end

  desc 'feature [NAME]', 'Creates a new feature'
  option :path,
         type: :string,
         required: false, desc: 'The path where your feature will be created', aliases: '-p'
  option :delete,
         type: :boolean,
         required: false, desc: 'This will delete the selected feature', aliases: '-d'

  def feature(name)
    path = options[:path] || load_config_path('feature')
    if options[:delete]
      Scaffolding.new([name, path]).delete_feature
    else
      Scaffolding.new([name, path]).generate_feature
    end
  end

  desc 'spec [SPEC_NAME]', 'Creates a new spec'
  option :path,
         type: :string, required: false, desc: 'The path where your spec will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected spec', aliases: '-d'

  def spec(name)
    path = options[:path] || load_config_path('spec')
    if options[:delete]
      Scaffolding.new([name, path]).delete_spec
    else
      Scaffolding.new([name, path]).generate_spec
    end
  end

  desc 'helper [HELPER_NAME]', 'Creates a new helper'
  option :path,
         type: :string, required: false, desc: 'The path where your helper will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected helper', aliases: '-d'

  def helper(name)
    path = options[:path] || load_config_path('helper')
    if options[:delete]
      Scaffolding.new([name, path]).delete_helper
    else
      Scaffolding.new([name, path]).generate_helper
    end
  end

  desc 'scaffold [SCAFFOLD_NAME]', 'It generates everything needed to start automating'

  def scaffold(name)
    if Pathname.new('spec').exist? && !Pathname.new('features').exist?
      Scaffolding.new([name, load_config_path('spec')]).generate_spec
    else
      Scaffolding.new([name, load_config_path('feature')]).generate_feature
    end
    Scaffolding.new([name, load_config_path('page')]).generate_class
  end

  desc 'config', 'Creates configuration file'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the config file', aliases: '-d'

  no_commands do
    def load_config_path(type)
      YAML.load_file('config/config.yml')["#{type}_path"] if Pathname.new('config/config.yml').exist?
    end
  end
end
