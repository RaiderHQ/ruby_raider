# frozen_string_literal: true

require_relative '../generators/menu_generator'
require_relative '../scaffolding/scaffolding'
require_relative '../commands/utility_commands'

class ScaffoldingCommands < UtilityCommands
  desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'

  def new(project_name)
    MenuGenerator.new(project_name).generate_choice_menu
  end

  map '-n' => 'new'

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

  map '-pg' => 'page'

  desc 'feature [NAME]', 'Creates a new feature'
  option :path,
         type: :string,
         required: false, desc: 'The path where your feature will be created', aliases: '-p'
  option :delete,
         type: :boolean,
         required: false, desc: 'This will delete the selected feature', aliases: '-d'
  option :open_ai,
         type: :string, required: false,
         desc: 'This will create the selected feature based on your prompt using open ai', aliases: '-o'

  def feature(name)
    path = options[:path] || load_config_path('feature')
    if options[:delete]
      Scaffolding.new([name, path]).delete_feature
    elsif options[:open_ai]
      path ||= 'features'
      mkdir(path)
      open_ai(options[:open_ai], "#{path}/#{name}.feature")
    else
      Scaffolding.new([name, path]).generate_feature
    end
  end

  map '-f' => 'feature'

  desc 'steps [NAME]', 'Creates a new step definitions file'
  option :path,
         type: :string,
         required: false, desc: 'The path where your feature will be created', aliases: '-p'
  option :open_ai,
         type: :string, required: false,
         desc: 'This will create the selected steps based on your prompt using open ai', aliases: '-o'
  option :input,
         type: :string,
         required: false, desc: 'It uses a file as input to create the steps', aliases: '-i'

  def steps(name)
    path = 'features/step_definitions'
    if options[:input]
      prompt = options[:open_ai] || 'create cucumber steps for the following scenarios in ruby'
      content = "#{prompt} #{File.read(options[:input])}"
      open_ai(content, "#{path}/#{name}_steps.rb")
    else
      open_ai(options[:open_ai], "#{path}/#{name}_steps.rb")
    end
  end

  map '-st' => 'steps'

  desc 'cuke [NAME]', 'Creates feature and step files only using open ai'
  option :prompt,
         type: :string,
         required: true, desc: 'The path where your feature will be created', aliases: '-p'

  def cuke(name)
    feature_path = "features/#{name}.feature"
    open_ai(options[:prompt], feature_path)
    prompt_step = "create cucumber steps for the following scenarios in ruby #{File.read(feature_path)}"
    open_ai(prompt_step, "features/step_definitions/#{name}_steps.rb")
  end

  map '-ck' => 'cuke'

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

  map '-s' => 'spec'

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

  map '-h' => 'helper'

  desc 'scaffold [SCAFFOLD_NAME]', 'It generates everything needed to start automating'

  def scaffold(name)
    if Pathname.new('spec').exist? && !Pathname.new('features').exist?
      Scaffolding.new([name, load_config_path('spec')]).generate_spec
    else
      Scaffolding.new([name, load_config_path('feature')]).generate_feature
    end
    Scaffolding.new([name, load_config_path('page')]).generate_class
  end

  map '-sf' => 'scaffold'

  desc 'config', 'Creates configuration file'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the config file', aliases: '-d'

  def config
    if options[:delete]
      Scaffolding.new.delete_config
    else
      Scaffolding.new.generate_config
    end
  end

  map '-c' => 'config'

  desc 'mkdir [NAME]', "Creates a directory if the directory doesn't exist"

  def mkdir(dir)
    Dir.mkdir(dir) unless Dir.exist?(dir)
  end

  no_commands do
    def load_config_path(type)
      YAML.load_file('config/config.yml')["#{type}_path"] if Pathname.new('config/config.yml').exist?
    end
  end
end
