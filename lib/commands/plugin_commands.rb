# frozen_string_literal: true

require 'thor'
require_relative '../plugin/plugin'

module RubyRaider
  # :reek:FeatureEnvy { enabled: false }
  # :reek:UtilityFunction { enabled: false }
  class PluginCommands < Thor
    desc 'add [NAME]', 'Adds a plugin to your project'

    def add(plugin_name)
      Plugin.add_plugin(plugin_name)
    end

    desc 'delete [NAME]', 'Deletes a plugin from your project'

    def delete(plugin_name)
      Plugin.delete_plugin(plugin_name)
    end

    desc 'local', 'Lists all the plugin in your project'

    def local
      pp Plugin.installed_plugins
    end

    desc 'list', 'Lists all the available plugin'

    def list
      pp Plugin.plugins
    end
  end
end
