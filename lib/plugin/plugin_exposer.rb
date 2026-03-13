# frozen_string_literal: true

require_relative '../plugin/plugin'

module RubyRaider
  module PluginExposer
    class << self
      FILE_PATH = File.expand_path('../commands/loaded_commands.rb', __dir__)
      # :reek:NestedIterators { enabled: false }
      def expose_commands(plugin_name)
        commands = read_loaded_commands
        return pp 'The plugin is already installed' if commands.any? { |l| l.include?(plugin_name) }

        has_subcommands = commands.any? { |l| l.include?('subcommand') }

        File.open(FILE_PATH, 'w') do |file|
          commands.each do |line|
            file.puts line
            file.puts "require '#{plugin_name}'" if line.include?("require 'thor'")
            if line.strip == 'class LoadedCommands < Thor' && !has_subcommands
              file.puts formatted_command_without_space(plugin_name)
            elsif line.strip == 'class LoadedCommands < Thor' && has_subcommands
              file.puts formatted_command_with_space(plugin_name)
            end
          end
        end
      end

      def remove_command(plugin_name)
        commands = read_loaded_commands
        return pp 'The plugin is not installed' unless commands.any? { |l| l.include?(plugin_name) }

        output_lines = commands.reject { |line| line.include?(plugin_name) }

        File.open(FILE_PATH, 'w') do |file|
          output_lines.each { |line| file.puts line }
        end
      end

      private

      def read_loaded_commands
        File.readlines(FILE_PATH)
      end

      def formatted_command_without_space(plugin_name)
        "desc '#{plugin_name}', 'Provides access to all the commands for #{plugin_name}'\n" \
        "subcommand '#{plugin_name}', #{Plugin.camelize(plugin_name)}::PluginCommands"
      end

      def formatted_command_with_space(plugin_name)
        "\n#{formatted_command_without_space(plugin_name)}"
      end
    end
  end
end
