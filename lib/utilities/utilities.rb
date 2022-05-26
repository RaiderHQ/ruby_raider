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

  def path=(path)
    @config['path'] = path
    overwrite_yaml
  end

  def url=(url)
    @config['url'] = url
    overwrite_yaml
  end

  def run
    if File.directory? 'spec'
      system 'rspec spec/'
    else
      system 'cucumber features'
    end
  end

  def overwrite_yaml
    File.open(@path, 'w') { |file| YAML.dump(@config, file) }
  end
end
