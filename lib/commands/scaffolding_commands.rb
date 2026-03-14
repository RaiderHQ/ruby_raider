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
  option :uses, type: :array, required: false,
                desc: 'Dependent pages to require', aliases: '-u'

  def page(name)
    generate_scaffolding(name, 'page', options[:path], uses: options[:uses])
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
  option :from, type: :string, required: false,
                desc: 'Generate spec stubs from an existing page object file', aliases: '-f'
  option :uses, type: :array, required: false,
                desc: 'Dependent pages to require', aliases: '-u'

  def spec(name)
    return generate_spec_from_page(name, options[:from]) if options[:from]

    generate_scaffolding(name, 'spec', options[:path], uses: options[:uses])
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
  option :with, type: :array, required: false,
                desc: 'Components to generate (page,spec,feature,steps,helper,component,model)', aliases: '-w'
  option :crud, type: :boolean, required: false,
                desc: 'Generate CRUD pages (list, create, detail, edit) + tests + model'
  option :uses, type: :array, required: false,
                desc: 'Dependent pages to require', aliases: '-u'

  def scaffold(*names)
    return interactive_scaffold if names.empty?

    names.each do |name|
      if options[:crud]
        generate_crud(name)
      elsif options[:with]
        generate_selected_components(name, options[:with])
      else
        generate_default_scaffold(name)
      end
    end
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

    def generate_scaffolding(name, type, path, uses: nil)
      path ||= load_config_path(type)
      scaffolding = Scaffolding.new([name, path])
      scaffolding.uses = Array(uses) if uses
      scaffolding.send("generate_#{type}")
    end

    def generate_default_scaffold(name)
      validate_project!
      uses = options[:uses]
      if Pathname.new('spec').exist? && !Pathname.new('features').exist?
        generate_scaffolding(name, 'spec', load_config_path('spec'), uses:)
      else
        generate_scaffolding(name, 'feature', load_config_path('feature'))
        generate_scaffolding(name, 'steps', load_config_path('steps'), uses:)
      end
      generate_scaffolding(name, 'page', load_config_path('page'), uses:)
    end

    def generate_selected_components(name, components)
      validate_project!
      uses = options[:uses]
      components.each do |comp|
        comp = comp.downcase.strip
        case comp
        when 'model'
          generate_model_data(name)
        else
          generate_scaffolding(name, comp, load_config_path(comp), uses:)
        end
      end
    end

    def generate_crud(name)
      require_relative '../scaffolding/crud_generator'
      validate_project!
      crud = CrudGenerator.new(name, Scaffolding, method(:load_config_path))
      generated = crud.generate
      say "Generated CRUD scaffold for: #{generated.join(', ')}"
    end

    def generate_spec_from_page(name, source_file)
      Scaffolding.new([name]).generate_spec_from_page(source_file)
    end

    def generate_model_data(name)
      normalized = NameNormalizer.normalize(name)
      path = "models/data/#{normalized}.yml"
      return if File.exist?(path)

      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, model_template(normalized))
    end

    def model_template(name)
      <<~YAML
        # Data model for #{name}
        default:
          name: 'Test #{name.capitalize}'
          email: 'test@example.com'

        valid:
          name: 'Valid #{name.capitalize}'
          email: 'valid@example.com'

        invalid:
          name: ''
          email: 'invalid'
      YAML
    end

    def interactive_scaffold
      require_relative '../scaffolding/scaffold_menu'
      validate_project!
      result = ScaffoldMenu.new.run
      return unless result

      result[:names].each do |name|
        result[:components].each do |comp|
          if comp == :model
            generate_model_data(name)
          else
            generate_scaffolding(name, comp.to_s, load_config_path(comp.to_s), uses: result[:uses])
          end
        end
      end
    end
  end
end
