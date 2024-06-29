# frozen_string_literal: true

require_relative '../lib/commands/scaffolding_commands'
require_relative '../lib/commands/utility_commands'

# :reek:FeatureEnvy { enabled: false }
# :reek:UtilityFunction { enabled: false }
module RubyRaider
  class Raider < Thor
    desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'
    option :parameters,
           type: :hash, required: false, desc: 'Parameters to avoid using the menu', aliases: '-p'

    def new(project_name)
      if options[:parameters]
        options[:parameters][:name] = project_name
        parsed_hash = options[:parameters].transform_keys(&:to_sym)
        return InvokeGenerators.generate_framework(parsed_hash)
      end

      MenuGenerator.new(project_name).generate_choice_menu
    end

    map '-n' => 'new'

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

    no_commands do
      def current_version = File.read(File.expand_path('version', __dir__)).strip
    end
  end
end
