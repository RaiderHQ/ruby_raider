# frozen_string_literal: true

require 'yaml'
require_relative 'plugin_exposer'

module RubyRaider
  module Plugin
    class << self
      def add_plugin(plugin_name)
        return pp 'The plugin was not found' unless available?(plugin_name)
        return pp 'The plugin is already installed' if installed?(plugin_name)

        pp "Adding #{plugin_name}..."
        add_plugin_to_gemfile(plugin_name)
        system('bundle install')
        PluginExposer.expose_commands(plugin_name)
        pp "The plugin #{plugin_name} is added"
      end

      def delete_plugin(plugin_name)
        return 'The plugin is not installed' unless installed_plugins.include?(plugin_name)

        pp "Deleting #{plugin_name}..."
        remove_plugin_from_gemfile(plugin_name)
        PluginExposer.remove_command(plugin_name)
        system('bundle install')
        pp "The plugin #{plugin_name} is deleted"
      end

      def installed_plugins
        parsed_gemfile = File.readlines('Gemfile').map { |line| line.sub('gem ', '').strip.delete("'") }
        parsed_gemfile.select { |line| available_plugins.include?(line) }
      end

      def available_plugins
        plugins['plugins']
      end

      def installed?(plugin_name)
        installed_plugins.include?(plugin_name)
      end

      def available?(plugin_name)
        available_plugins.include?(plugin_name)
      end

      def camelize(str)
        str.split('_').collect(&:capitalize).join
      end

      private

      def add_plugin_to_gemfile(plugin_name)
        File.open('Gemfile', 'a') do |file|
          file.puts "\n# Ruby Raider Plugins\n" unless comment_present?
          file.puts "gem '#{plugin_name}'" unless plugin_present?(plugin_name)
        end
      end

      def remove_plugin_from_gemfile(plugin_name)
        output_lines = remove_plugins_and_comments(plugin_name)
        update_gemfile(output_lines)
      end

      def last_plugin?
        installed_plugins.count == 1
      end

      def plugins
        @plugins ||= YAML.load_file(File.expand_path('plugins.yml'))
      end

      def read_gemfile
        File.readlines('Gemfile')
      end

      def comment_present?
        read_gemfile.grep(/Ruby Raider Plugins/).any?
      end

      def plugin_present?(plugin_name)
        read_gemfile.grep(/#{plugin_name}/).any?
      end

      def remove_plugins_and_comments(plugin_name)
        read_gemfile.reject do |line|
          line.include?(plugin_name) || line.include?('Ruby Raider Plugins') && last_plugin?
        end
      end

      # :reek:NestedIterators { enabled: false }
      def update_gemfile(output_lines)
        File.open('Gemfile', 'w') do |file|
          output_lines.each { |line| file.puts line }
        end
      end
    end
  end
end