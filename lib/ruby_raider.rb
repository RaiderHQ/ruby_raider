# frozen_string_literal: true

require 'thor'

# Lazy-load top-level command classes to reduce CLI startup time.
autoload :ScaffoldingCommands, File.expand_path('commands/scaffolding_commands', __dir__)
autoload :UtilityCommands, File.expand_path('commands/utility_commands', __dir__)

module RubyRaider
  class Raider < Thor
    def self.exit_on_failure? = true

    no_tasks do
      def current_version = File.read(File.expand_path('version', __dir__)).strip
    end

    desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'
    option :parameters,
           type: :hash, required: false, desc: 'Parameters to avoid using the menu', aliases: 'p'
    option :accessibility,
           type: :boolean, required: false, desc: 'Add axe accessibility testing'
    def new(project_name)
      require_relative 'utilities/logo'
      RubyRaider::Logo.display
      params = options[:parameters]
      if params
        params[:name] = project_name
        parsed_hash = params.transform_keys(&:to_sym)
        merge_flags(parsed_hash)
        return generate_from_parameters(parsed_hash)
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
      # -p values arrive as strings; only examples:false turns the example tests off
      def generate_from_parameters(params)
        params[:examples] = params[:examples].to_s.downcase != 'false' if params.key?(:examples)
        InvokeGenerators.generate_framework(params)
      end

      def merge_flags(params)
        params[:accessibility] = true if options[:accessibility]
      end
    end
  end
end
