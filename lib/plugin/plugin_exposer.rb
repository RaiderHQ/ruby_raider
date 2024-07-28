# frozen_string_literal: true

require 'thor'

module RubyRaider
  module PluginExposer
    def self.expose_commands(plugin_name)
      File.new('lib/commands/loaded_commands.rb', 'w') unless File.exist?('lib/commands/loaded_commands.rb')
      File.open('lib/commands/loaded_commands.rb', 'w') do |file|
        file.puts '# frozen_string_literal: true'
        file.puts
        file.puts 'require \'thor\''
        file.puts "require \'#{plugin_name}\'"
        file.puts 'require_relative \'../plugin/plugin\''
        file.puts
        file.puts 'module RubyRaider'
        file.puts '  class LoadedCommands < Thor'
        file.puts "    desc \'#{plugin_name} [COMMAND] [NAME]\', \'Plugin commands\'"
        file.puts
        file.puts '    subcommand \'great_axe\', GreatAxe::PluginCommands'
        file.puts '  end'
        file.puts 'end'
      end
    end

    def self.remove_command(plugin_name)
      File.open('lib/commands/loaded_commands.rb', 'w') do |file|
        file.puts '# frozen_string_literal: true'
        file.puts
        file.puts 'require \'thor\''
        file.puts 'require_relative \'../plugin/plugin\''
        file.puts
        file.puts 'module RubyRaider'
        file.puts '  class LoadedCommands < Thor'
        file.puts '  end'
        file.puts 'end'
      end
    end
  end
end
