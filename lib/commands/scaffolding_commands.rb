# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'pathname'
require_relative '../generators/menu_generator'
require_relative '../scaffolding/scaffolding'
require_relative '../scaffolding/name_normalizer'
require_relative '../scaffolding/project_detector'
require_relative '../commands/utility_commands'

class ScaffoldingCommands < Thor
  desc 'page [PAGE_NAME]', 'Creates a new page object'
  option :path, type: :string, required: false,
                desc: 'The path where your page will be created', aliases: '-p'

  def page(name)
    generate_scaffolding(name, 'page', options[:path])
  end

  desc 'feature [NAME]', 'Creates a new feature'
  option :path, type: :string, required: false,
                desc: 'The path where your feature will be created', aliases: '-p'

  def feature(name)
    generate_scaffolding(name, 'feature', options[:path])
  end

  desc 'spec [SPEC_NAME]', 'Creates a new spec'
  option :path, type: :string, required: false,
                desc: 'The path where your spec will be created', aliases: '-p'

  def spec(name)
    generate_scaffolding(name, 'spec', options[:path])
  end

  desc 'helper [HELPER_NAME]', 'Creates a new helper'
  option :path, type: :string, required: false,
                desc: 'The path where your helper will be created', aliases: '-p'

  def helper(name)
    generate_scaffolding(name, 'helper', options[:path])
  end

  desc 'steps [STEPS_NAME]', 'Creates a new steps definition'
  option :path, type: :string, required: false,
                desc: 'The path where your steps will be created', aliases: '-p'

  def steps(name)
    generate_scaffolding(name, 'steps', options[:path])
  end

  desc 'component [NAME]', 'Creates a component inheriting from Component'
  option :path, type: :string, required: false,
                desc: 'The path where your component will be created', aliases: '-p'

  def component(name)
    generate_scaffolding(name, 'component', options[:path])
  end

  desc 'scaffold [NAMES...]', 'Generates pages, specs/features, and helpers for one or more names'

  def scaffold(*names)
    names.each { |name| generate_default_scaffold(name) }
  end

  no_commands do
    def load_config_path(type)
      ScaffoldProjectDetector.config_path(type)
    end

    def validate_project!
      warnings = ScaffoldProjectDetector.validate_project
      warnings.each { |w| say "Warning: #{w}", :yellow }
      show_detection_defaults
    end

    def show_detection_defaults
      gemfile = ScaffoldProjectDetector.read_gemfile
      if gemfile.empty?
        say 'Warning: No Gemfile found, defaulting to selenium + rspec templates.', :yellow
      else
        automation = ScaffoldProjectDetector.detect_automation(gemfile)
        framework = ScaffoldProjectDetector.detect_framework(gemfile)
        if automation.nil?
          say 'Warning: Could not detect automation library from Gemfile, defaulting to selenium.', :yellow
        end
        say 'Warning: Could not detect test framework from Gemfile, defaulting to rspec.', :yellow if framework.nil?
      end
    end

    def generate_scaffolding(name, type, path)
      path ||= load_config_path(type)
      scaffolding = Scaffolding.new([name, path])
      scaffolding.send("generate_#{type}")
    end

    def generate_default_scaffold(name)
      validate_project!
      if Pathname.new('spec').exist? && !Pathname.new('features').exist?
        generate_scaffolding(name, 'spec', load_config_path('spec'))
      else
        generate_scaffolding(name, 'feature', load_config_path('feature'))
        generate_scaffolding(name, 'steps', load_config_path('steps'))
      end
      generate_scaffolding(name, 'page', load_config_path('page'))
    end
  end
end
