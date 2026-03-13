# frozen_string_literal: true

require 'yaml'
require_relative 'plugin_exposer'

module RubyRaider
  module Plugin
    class << self
      def add_plugin(plugin_name)
        return gemfile_guard unless File.exist?('Gemfile')
        return pp 'The plugin was not found' unless available?(plugin_name)
        return pp 'The plugin is already installed' if installed?(plugin_name)

        pp "Adding #{plugin_name}..."
        add_plugin_to_gemfile(plugin_name)
        invalidate_gemfile_cache
        system('bundle install')
        PluginExposer.expose_commands(plugin_name)
        pp "The plugin #{plugin_name} is added"
      end

      def delete_plugin(plugin_name)
        return gemfile_guard unless File.exist?('Gemfile')
        return 'The plugin is not installed' unless installed_plugins.include?(plugin_name)

        pp "Deleting #{plugin_name}..."
        remove_plugin_from_gemfile(plugin_name)
        invalidate_gemfile_cache
        PluginExposer.remove_command(plugin_name)
        system('bundle install')
        pp "The plugin #{plugin_name} is deleted"
      end

      def installed_plugins
        return gemfile_guard unless File.exist?('Gemfile')

        cached_gemfile_lines.filter_map do |line|
          stripped = line.sub('gem ', '').strip.delete("'")
          stripped if plugins.include?(stripped)
        end
      end

      def installed?(plugin_name)
        installed_plugins.include?(plugin_name)
      end

      def available?(plugin_name)
        plugins.include?(plugin_name)
      end

      def camelize(str)
        str.split('_').collect(&:capitalize).join
      end

      def plugins
        ['great_axe']
      end

      private

      # Read Gemfile once and cache until explicitly invalidated
      def cached_gemfile_lines
        @cached_gemfile_lines ||= File.readlines('Gemfile')
      end

      def invalidate_gemfile_cache
        @cached_gemfile_lines = nil
      end

      def add_plugin_to_gemfile(plugin_name)
        return gemfile_guard unless File.exist?('Gemfile')

        lines = cached_gemfile_lines
        has_comment = lines.any? { |l| l.include?('Ruby Raider Plugins') }
        has_plugin = lines.any? { |l| l.include?(plugin_name) }

        File.open('Gemfile', 'a') do |file|
          file.puts "\n# Ruby Raider Plugins\n" unless has_comment
          file.puts "gem '#{plugin_name}'" unless has_plugin
        end
      end

      def remove_plugin_from_gemfile(plugin_name)
        output_lines = remove_plugins_and_comments(plugin_name)
        update_gemfile(output_lines)
      end

      def last_plugin?
        installed_plugins.count == 1
      end

      def remove_plugins_and_comments(plugin_name)
        cached_gemfile_lines.reject do |line|
          line.include?(plugin_name) || line.include?('Ruby Raider Plugins') && last_plugin?
        end
      end

      def update_gemfile(output_lines)
        return gemfile_guard unless File.exist?('Gemfile')

        File.open('Gemfile', 'w') do |file|
          output_lines.each { |line| file.puts line }
        end
      end

      def gemfile_guard
        pp 'There is no Gemfile, please create one to install plugins'
      end
    end
  end
end
