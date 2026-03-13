# frozen_string_literal: true

require 'thor'
require 'fileutils'
require_relative '../generators/menu_generator'
require_relative '../scaffolding/scaffolding'
require_relative '../scaffolding/name_normalizer'
require_relative '../scaffolding/dry_run_presenter'
require_relative '../scaffolding/project_detector'
require_relative '../commands/utility_commands'

class ScaffoldingCommands < Thor
  class_option :dry_run, type: :boolean, default: false,
                         desc: 'Preview files without creating them', banner: ''

  desc 'page [PAGE_NAME]', 'Creates a new page object'
  option :path, type: :string, required: false,
                desc: 'The path where your page will be created', aliases: '-p'
  option :delete, type: :boolean, required: false,
                  desc: 'This will delete the selected page', aliases: '-d'
  option :uses, type: :array, required: false,
                desc: 'Dependent pages to require', aliases: '-u'

  def page(name)
    return delete_scaffolding(name, 'page') if options[:delete]
    return dry_run_preview(name, 'page') if options[:dry_run]

    generate_scaffolding(name, 'page', options[:path], uses: options[:uses])
  end

  desc 'feature [NAME]', 'Creates a new feature'
  option :path, type: :string, required: false,
                desc: 'The path where your feature will be created', aliases: '-p'
  option :delete, type: :boolean, required: false,
                  desc: 'This will delete the selected feature', aliases: '-d'

  def feature(name)
    return delete_scaffolding(name, 'feature') if options[:delete]
    return dry_run_preview(name, 'feature') if options[:dry_run]

    generate_scaffolding(name, 'feature', options[:path])
  end

  desc 'spec [SPEC_NAME]', 'Creates a new spec'
  option :path, type: :string, required: false,
                desc: 'The path where your spec will be created', aliases: '-p'
  option :delete, type: :boolean, required: false,
                  desc: 'This will delete the selected spec', aliases: '-d'
  option :from, type: :string, required: false,
                desc: 'Generate spec stubs from an existing page object file', aliases: '-f'
  option :uses, type: :array, required: false,
                desc: 'Dependent pages to require', aliases: '-u'
  option :ai, type: :boolean, default: false,
              desc: 'Use LLM to generate meaningful test scenarios'

  def spec(name)
    return delete_scaffolding(name, 'spec') if options[:delete]
    return dry_run_preview(name, 'spec') if options[:dry_run]
    return generate_spec_from_page(name, options[:from], ai: options[:ai]) if options[:from]

    generate_scaffolding(name, 'spec', options[:path], uses: options[:uses])
  end

  desc 'helper [HELPER_NAME]', 'Creates a new helper'
  option :path, type: :string, required: false,
                desc: 'The path where your helper will be created', aliases: '-p'
  option :delete, type: :boolean, required: false,
                  desc: 'This will delete the selected helper', aliases: '-d'

  def helper(name)
    return delete_scaffolding(name, 'helper') if options[:delete]
    return dry_run_preview(name, 'helper') if options[:dry_run]

    generate_scaffolding(name, 'helper', options[:path])
  end

  desc 'steps [STEPS_NAME]', 'Creates a new steps definition'
  option :path, type: :string, required: false,
                desc: 'The path where your steps will be created', aliases: '-p'
  option :delete, type: :boolean, required: false,
                  desc: 'This will delete the selected steps', aliases: '-d'

  def steps(name)
    return delete_scaffolding(name, 'steps') if options[:delete]
    return dry_run_preview(name, 'steps') if options[:dry_run]

    generate_scaffolding(name, 'steps', options[:path])
  end

  desc 'component [NAME]', 'Creates a component inheriting from Component'
  option :path, type: :string, required: false,
                desc: 'The path where your component will be created', aliases: '-p'
  option :delete, type: :boolean, required: false,
                  desc: 'This will delete the selected component', aliases: '-d'

  def component(name)
    return delete_scaffolding(name, 'component') if options[:delete]
    return dry_run_preview(name, 'component') if options[:dry_run]

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

  desc 'destroy [NAMES...]', 'Removes all scaffolded files for the given names (page, spec/feature, steps)'
  option :with, type: :array, required: false,
                desc: 'Components to destroy (page,spec,feature,steps,helper,component)', aliases: '-w'

  def destroy(*names)
    if names.empty?
      say 'Please provide at least one name to destroy', :red
      return
    end

    names.each { |name| destroy_scaffold(name, options[:with]) }
  end

  map 'd' => 'destroy'

  desc 'from_url [URL]', 'Generates page object and spec from a live URL'
  option :name, type: :string, required: false,
                desc: 'Override the page object name', aliases: '-n'
  option :ai, type: :boolean, default: false,
              desc: 'Use LLM for intelligent page analysis'

  def from_url(url)
    require_relative '../scaffolding/url_analyzer'
    analyzer = UrlAnalyzer.new(url, name_override: options[:name], ai: options[:ai])
    analysis = analyzer.analyze.to_h

    page_name = analysis[:page_name]

    if options[:dry_run]
      DryRunPresenter.preview([
                                "page_objects/pages/#{page_name}.rb",
                                "spec/#{page_name}_spec.rb"
                              ])
      return
    end

    Scaffolding.new([page_name]).generate_page_from_url(analysis)
    Scaffolding.new([page_name]).generate_spec_from_url(analysis)
    say "Generated page object and spec for #{url}"
  end

  no_commands do
    def load_config_path(type)
      YAML.load_file('config/config.yml')["#{type}_path"] if Pathname.new('config/config.yml').exist?
    end

    def delete_scaffolding(name, type)
      Scaffolding.new([name]).send("delete_#{type}")
    end

    def generate_scaffolding(name, type, path, uses: nil)
      path ||= load_config_path(type)
      scaffolding = Scaffolding.new([name, path])
      scaffolding.uses = Array(uses) if uses
      scaffolding.send("generate_#{type}")
    end

    def dry_run_preview(name, type)
      path = options[:path] || load_config_path(type)
      file = Scaffolding.planned_path(name, type, path)
      DryRunPresenter.preview([file])
    end

    def generate_default_scaffold(name)
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
      if options[:dry_run]
        crud = CrudGenerator.new(name, Scaffolding, method(:load_config_path))
        DryRunPresenter.preview(crud.planned_files)
        return
      end
      crud = CrudGenerator.new(name, Scaffolding, method(:load_config_path))
      generated = crud.generate
      say "Generated CRUD scaffold for: #{generated.join(', ')}"
    end

    def generate_spec_from_page(name, source_file, ai: false) # rubocop:disable Naming/MethodParameterName
      Scaffolding.new([name]).generate_spec_from_page(source_file, ai:)
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

    def destroy_scaffold(name, components = nil)
      types = components ? components.map { |c| c.downcase.strip } : detect_scaffold_types
      types.each { |type| delete_scaffolding(name, type) }
    end

    def detect_scaffold_types
      if Pathname.new('spec').exist? && !Pathname.new('features').exist?
        %w[page spec]
      else
        %w[page feature steps]
      end
    end

    def interactive_scaffold
      require_relative '../scaffolding/scaffold_menu'
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
