# frozen_string_literal: true

require_relative '../plugin/plugin'

module RubyRaider
  module PluginExposer
    class << self
      FILE_PATH = File.expand_path('../commands/loaded_commands.rb', __dir__)
      # :reek:NestedIterators { enabled: false }
      def expose_commands(plugin_name)
        return pp 'The plugin is already installed' if plugin_present?(plugin_name)

        commands = read_loaded_commands

        File.open(FILE_PATH, 'w') do |file|
          commands.each do |line|
            file.puts line
            file.puts require_plugin(plugin_name, line)
            file.puts select_command_formatting(plugin_name, line)
          end
        end
      end

      def remove_command(plugin_name)
        return pp 'The plugin is not installed' unless plugin_present?(plugin_name)

        delete_plugin_command(plugin_name)
      end

      private

      def any_commands?
        read_loaded_commands.any? { |line| line.include?('subcommand') }
      end

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

      def plugin_present?(plugin_name)
        read_loaded_commands.grep(/#{plugin_name}/).any?
      end

      def select_command_formatting(plugin_name, line)
        if line.strip == 'class LoadedCommands < Thor' && !any_commands?
          formatted_command_without_space(plugin_name)
        elsif any_commands?
          formatted_command_with_space(plugin_name)
        end
      end

      def require_plugin(plugin_name, line)
        "require '#{plugin_name}'" if line.include?("require 'thor'") && !plugin_present?(plugin_name)
      end

      # :reek:NestedIterators { enabled: false }
      def delete_plugin_command(plugin_name)
        output_lines = read_loaded_commands.reject do |line|
          line.include?(plugin_name) if plugin_present?(plugin_name)
        end

        File.open(FILE_PATH, 'w') do |file|
          output_lines.each { |line| file.puts line }
        end
      end
    end
  end
end
