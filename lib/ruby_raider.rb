# frozen_string_literal: true

require_relative '../lib/plugin/plugin'
require_relative '../lib/commands/plugin_commands'
require_relative '../lib/commands/loaded_commands'
require_relative '../lib/commands/scaffolding_commands'
require_relative '../lib/commands/utility_commands'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
module RubyRaider
  class Raider < Thor
    no_tasks do
      def self.plugin_commands?
        File.readlines(File.expand_path('commands/loaded_commands.rb', __dir__)).any? do |line|
          line.include?('subcommand')
        end
      end

      def current_version = File.read(File.expand_path('version', __dir__)).strip
    end

    desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'
    option :parameters,
           type: :hash, required: false, desc: 'Parameters to avoid using the menu', aliases: 'p'

    def new(project_name)
      params = options[:parameters]
      if params
        params[:name] = project_name
        parsed_hash = params.transform_keys(&:to_sym)
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

    desc 'plugin_manager', 'Provides access to all the commands to manager your plugins'
    subcommand 'plugin_manager', PluginCommands
    map 'pm' => 'plugin_manager'

    if plugin_commands?
      desc 'plugins', 'loaded plugin commands'
      subcommand 'plugins', LoadedCommands
      map 'ps' => 'plugins'
    end
  end
end
