# frozen_string_literal: true

require 'yaml'

class Utilities
  def initialize
    @path = 'config/config.yml'
    @config = YAML.load_file(@path)
  end

  def browser=(browser)
    @config['browser'] = browser
    overwrite_yaml
  end

  def page_path=(path)
    @config['page_path'] = path
    overwrite_yaml
  end

  def spec_path=(path)
    @config['spec_path'] = path
    overwrite_yaml
  end

  def feature_path=(path)
    @config['feature_path'] = path
    overwrite_yaml
  end

  def helper_path=(path)
    @config['helper_path'] = path
    overwrite_yaml
  end

  def url=(url)
    @config['url'] = url
    overwrite_yaml
  end

  def platform=(platform)
    @config['platform'] = platform
    overwrite_yaml
  end

  def browser_options=(*opts)
    @config['browser_options'] = opts.flatten
    overwrite_yaml
  end

  def delete_browser_options
    @config.delete('browser_options')
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

  def overwrite_yaml
    File.open(@path, 'w') { |file| YAML.dump(@config, file) }
  end
end
