# frozen_string_literal: true

require 'yaml'

module Utilities
  @path = 'config/config.yml'

  class << self
    def browser=(browser)
      set('browser', browser.to_s.delete_prefix(':'))
    end

    def page_path=(path)
      set('page_path', path)
    end

    def spec_path=(path)
      set('spec_path', path)
    end

    def feature_path=(path)
      set('feature_path', path)
    end

    def helper_path=(path)
      set('helper_path', path)
    end

    def url=(url)
      set('url', url)
    end

    def timeout=(seconds)
      set('timeout', seconds.to_i)
    end

    def viewport=(dimensions)
      width, height = dimensions.split('x').map(&:to_i)
      set('viewport', { 'width' => width, 'height' => height })
    end

    def platform=(platform)
      set('platform', platform)
    end

    def browser_options=(opts)
      reload_config
      browser_name = @config['browser'] || 'chrome'
      @config['browser_arguments'] ||= {}
      @config['browser_arguments'][browser_name] = Array(opts).flatten
      overwrite_yaml
    end

    def delete_browser_options
      reload_config
      browser_name = @config['browser'] || 'chrome'
      @config['browser_arguments']&.delete(browser_name)
      overwrite_yaml
    end

    def headless=(enabled)
      set('headless', enabled)
    end

    def debug=(enabled)
      reload_config
      @config['debug'] ||= {}
      @config['debug']['enabled'] = enabled
      overwrite_yaml
    end

    # Set multiple config keys in a single YAML write.
    # Usage: Utilities.batch_update(browser: 'chrome', timeout: 30)
    def batch_update(**settings)
      reload_config
      settings.each { |key, value| @config[key.to_s] = value }
      overwrite_yaml
    end

    def run(opts = nil)
      command = File.directory?('spec') ? 'rspec spec/' : 'cucumber features'
      system "#{command} #{opts}"
    end

    def parallel_run(opts = nil, _settings = nil)
      command = File.directory?('spec') ? 'parallel_rspec spec/' : 'parallel_cucumber features'
      system "#{command} #{opts}"
    end

    private

    # Single-key setter: reloads from disk, updates, and writes back
    def set(key, value)
      reload_config
      @config[key] = value
      overwrite_yaml
    end

    def overwrite_yaml
      File.open(@path, 'w') { |file| YAML.dump(@config, file) }
    end

    # Always reload from disk so external changes (e.g. desktop app) are picked up
    def reload_config
      @config = File.exist?(@path) ? YAML.load_file(@path) : {}
    end

    def config
      @config || reload_config
    end
  end
end
