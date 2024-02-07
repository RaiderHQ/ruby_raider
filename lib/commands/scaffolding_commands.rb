# frozen_string_literal: true

require 'thor'
require_relative '../generators/menu_generator'
require_relative '../scaffolding/scaffolding'
require_relative '../commands/utility_commands'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
class ScaffoldingCommands < Thor
  desc 'page [PAGE_NAME]', 'Creates a new page object'
  option :path,
         type: :string, required: false, desc: 'The path where your page will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected page', aliases: '-d'

  def page(name)
    return delete_scaffolding(name, 'page', options[:path]) if options[:delete]

    generate_scaffolding(name, 'page', options[:path])
  end

  desc 'feature [NAME]', 'Creates a new feature'
  option :path,
         type: :string,
         required: false, desc: 'The path where your feature will be created', aliases: '-p'
  option :delete,
         type: :boolean,
         required: false, desc: 'This will delete the selected feature', aliases: '-d'

  def feature(name)
    return delete_scaffolding(name, 'feature', options[:path]) if options[:delete]

    generate_scaffolding(name, 'feature', options[:path])
  end

  desc 'spec [SPEC_NAME]', 'Creates a new spec'
  option :path,
         type: :string, required: false, desc: 'The path where your spec will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected spec', aliases: '-d'

  def spec(name)
    return delete_scaffolding(name, 'spec', options[:path]) if options[:delete]

    generate_scaffolding(name, 'spec', options[:path])
  end

  desc 'helper [HELPER_NAME]', 'Creates a new helper'
  option :path,
         type: :string, required: false, desc: 'The path where your helper will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected helper', aliases: '-d'

  def helper(name)
    return delete_scaffolding(name, 'helper', options[:path]) if options[:delete]

    generate_scaffolding(name, 'helper', options[:path])
  end

  desc 'steps [STEPS_NAME]', 'Creates a new steps definition'
  option :path,
         type: :string, required: false, desc: 'The path where your steps will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected steps', aliases: '-d'

  def steps(name)
    return delete_scaffolding(name, 'steps', options[:path]) if options[:delete]

    generate_scaffolding(name, 'steps', options[:path])
  end

  desc 'scaffold [SCAFFOLD_NAME]', 'It generates everything needed to start automating'

  def scaffold(name)
    if Pathname.new('spec').exist? && !Pathname.new('features').exist?
      Scaffolding.new([name, load_config_path('spec')]).generate_spec
    else
      Scaffolding.new([name, load_config_path('feature')]).generate_feature
      Scaffolding.new([name, load_config_path('steps')]).generate_steps
    end
    Scaffolding.new([name, load_config_path('page')]).generate_page
  end

  no_commands do
    def load_config_path(type)
      YAML.load_file('config/config.yml')["#{type}_path"] if Pathname.new('config/config.yml').exist?
    end

    def delete_scaffolding(name, type, path)
      path ||= load_config_path(type)
      Scaffolding.new([name, path]).send("delete_#{type}")
    end

    def generate_scaffolding(name, type, path)
      path ||= load_config_path(type)
      Scaffolding.new([name, path]).send("generate_#{type}")
    end
  end
end
