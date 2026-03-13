# frozen_string_literal: true

require 'thor'

# Lazy-load top-level command classes to reduce CLI startup time.
autoload :AdoptCommands, File.expand_path('commands/adopt_commands', __dir__)
autoload :ScaffoldingCommands, File.expand_path('commands/scaffolding_commands', __dir__)
autoload :UtilityCommands, File.expand_path('commands/utility_commands', __dir__)

module RubyRaider
  # Lazy-load namespaced classes within the correct module scope.
  autoload :Plugin, File.expand_path('plugin/plugin', __dir__)
  autoload :PluginCommands, File.expand_path('commands/plugin_commands', __dir__)
  autoload :LoadedCommands, File.expand_path('commands/loaded_commands', __dir__)

  class Raider < Thor
    no_tasks do
      def self.plugin_commands?
        @plugin_commands ||= File.read(
          File.expand_path('commands/loaded_commands.rb', __dir__)
        ).include?('subcommand')
      end

      def current_version = File.read(File.expand_path('version', __dir__)).strip
    end

    desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'
    option :parameters,
           type: :hash, required: false, desc: 'Parameters to avoid using the menu', aliases: 'p'
    option :skip_ci,
           type: :boolean, required: false, desc: 'Skip CI/CD configuration generation'
    option :skip_allure,
           type: :boolean, required: false, desc: 'Skip Allure reporting setup'
    option :skip_video,
           type: :boolean, required: false, desc: 'Skip video recording setup'
    option :reporter,
           type: :string, required: false, desc: 'Reporter: allure, junit, json, both, all, none', aliases: '-r'
    option :accessibility,
           type: :boolean, required: false, desc: 'Add axe accessibility testing'
    option :visual,
           type: :boolean, required: false, desc: 'Add visual regression testing'
    option :performance,
           type: :boolean, required: false, desc: 'Add Lighthouse performance auditing'
    option :ruby_version,
           type: :string, required: false, desc: 'Ruby version for generated project (e.g. 3.4, 3.3)'

    def new(project_name)
      require_relative 'utilities/logo'
      RubyRaider::Logo.display
      params = options[:parameters]
      if params
        params[:name] = project_name
        parsed_hash = params.transform_keys(&:to_sym)
        merge_skip_flags(parsed_hash)
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

    desc 'adopt', 'Adopts an existing test project into Ruby Raider conventions'
    subcommand 'adopt', AdoptCommands
    map 'a' => 'adopt'

    desc 'generate', 'Provides access to all the scaffolding commands'
    subcommand 'generate', ScaffoldingCommands
    map 'g' => 'generate'

    desc 'utility', 'Provides access to all the utility commands'
    subcommand 'utility', UtilityCommands
    map 'u' => 'utility'

    desc 'plugin_manager', 'Provides access to all the commands to manager your plugins'
    subcommand 'plugin_manager', PluginCommands
    map 'pm' => 'plugin_manager'

    if plugin_commands?
      desc 'plugins', 'loaded plugin commands'
      subcommand 'plugins', LoadedCommands
      map 'ps' => 'plugins'
    end

    no_tasks do
      def merge_skip_flags(params)
        %i[skip_ci skip_allure skip_video].each do |flag|
          params[flag] = true if options[flag]
        end
        params[:reporter] = options[:reporter] if options[:reporter]
        params[:accessibility] = true if options[:accessibility]
        params[:visual] = true if options[:visual]
        params[:performance] = true if options[:performance]
        params[:ruby_version] = options[:ruby_version] if options[:ruby_version]
      end
    end
  end
end
