# frozen_string_literal: true

require 'yaml'

module Utilities
  @path = 'config/config.yml'

  class << self
    def browser=(browser)
      set('browser', browser)
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
      browser_name = config['browser'] || 'chrome'
      config['browser_arguments'] ||= {}
      config['browser_arguments'][browser_name] = Array(opts).flatten
      overwrite_yaml
    end

    def delete_browser_options
      browser_name = config['browser'] || 'chrome'
      config['browser_arguments']&.delete(browser_name)
      overwrite_yaml
    end

    def headless=(enabled)
      set('headless', enabled)
    end

    def llm_provider=(provider)
      set('llm_provider', provider)
    end

    def llm_api_key=(key)
      set('llm_api_key', key)
    end

    def llm_model=(model)
      set('llm_model', model)
    end

    def llm_url=(url)
      set('llm_url', url)
    end

    def debug=(enabled)
      config['debug'] ||= {}
      config['debug']['enabled'] = enabled
      overwrite_yaml
    end

    # Set multiple config keys in a single YAML write.
    # Usage: Utilities.batch_update(browser: 'chrome', timeout: 30)
    def batch_update(**settings)
      settings.each { |key, value| config[key.to_s] = value }
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

    # Single-key setter: updates in-memory config and writes once
    def set(key, value)
      config[key] = value
      overwrite_yaml
    end

    def overwrite_yaml
      File.open(@path, 'w') { |file| YAML.dump(config, file) }
    end

    def config
      @config ||= File.exist?(@path) ? YAML.load_file(@path) : nil
    end
  end
end
