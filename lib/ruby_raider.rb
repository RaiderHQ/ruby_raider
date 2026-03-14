# frozen_string_literal: true

require 'thor'

# Lazy-load top-level command classes to reduce CLI startup time.
autoload :ScaffoldingCommands, File.expand_path('commands/scaffolding_commands', __dir__)
autoload :UtilityCommands, File.expand_path('commands/utility_commands', __dir__)

module RubyRaider
  class Raider < Thor
    no_tasks do
      def current_version = File.read(File.expand_path('version', __dir__)).strip
    end

    desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'
    option :parameters,
           type: :hash, required: false, desc: 'Parameters to avoid using the menu', aliases: 'p'
    option :accessibility,
           type: :boolean, required: false, desc: 'Add axe accessibility testing'
    option :visual,
           type: :boolean, required: false, desc: 'Add visual regression testing'
    option :performance,
           type: :boolean, required: false, desc: 'Add Lighthouse performance auditing'

    def new(project_name)
      require_relative 'utilities/logo'
      RubyRaider::Logo.display
      params = options[:parameters]
      if params
        params[:name] = project_name
        parsed_hash = params.transform_keys(&:to_sym)
        merge_flags(parsed_hash)
        return InvokeGenerators.generate_framework(parsed_hash)
      end

      MenuGenerator.new(project_name).generate_choice_menu
    end

    map 'n' => 'new'

    desc 'version', 'It shows the version of Ruby Raider you are currently using'

    def version
      puts "The version is #{current_version}, happy testing!"
    end

    map 'v' => 'version'

    desc 'generate', 'Provides access to all the scaffolding commands'
    subcommand 'generate', ScaffoldingCommands
    map 'g' => 'generate'

    desc 'utility', 'Provides access to all the utility commands'
    subcommand 'utility', UtilityCommands
    map 'u' => 'utility'

    no_tasks do
      def merge_flags(params)
        params[:accessibility] = true if options[:accessibility]
        params[:visual] = true if options[:visual]
        params[:performance] = true if options[:performance]
      end
    end
  end
end
