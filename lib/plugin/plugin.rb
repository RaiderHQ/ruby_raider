# frozen_string_literal: true

require 'yaml'

module RubyRaider
  module Plugin
    class << self
      def add_plugin(plugin_name)
        return pp 'The plugin was not found' unless available?(plugin_name)
        return pp 'The plugin is already installed' if installed?(plugin_name)

        pp "Adding #{plugin_name}..."
        add_plugin_to_gemfile(plugin_name)
        system('bundle install')
        pp "The plugin #{plugin_name} is added"
      end

      def delete_plugin(plugin_name)
        return 'The plugin is not installed' unless installed_plugins.include?(plugin_name)

        pp "Deleting #{plugin_name}..."
        remove_plugin_from_gemfile(plugin_name)
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
          file.puts "\n# Ruby Raider Plugins\n" unless File.readlines('Gemfile').grep(/Ruby Raider Plugins/).any?
          file.puts "gem '#{plugin_name}'" unless File.readlines('Gemfile').grep(/#{plugin_name}/).any?
        end
      end

      def remove_plugin_from_gemfile(plugin_name)
        input_lines = File.readlines('Gemfile')
        output_lines = input_lines.reject do |line|
          line.include?(plugin_name) || line.include?('Ruby Raider Plugins') && last_plugin?
        end
        File.open('Gemfile', 'w') do |file|
          output_lines.each { |line| file.puts line }
        end
      end

      def last_plugin?
        installed_plugins.count == 1
      end

      def plugins
        @plugins ||= YAML.load_file('plugins.yml')
      end
    end
  end
end
