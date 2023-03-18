# frozen_string_literal: true

require 'yaml'
require 'faraday'

module Utilities
  @path = 'config/config.yml'

  class << self
    def browser=(browser)
      config['browser'] = browser
      overwrite_yaml
    end

    def page_path=(path)
      config['page_path'] = path
      overwrite_yaml
    end

    def spec_path=(path)
      config['spec_path'] = path
      overwrite_yaml
    end

    def feature_path=(path)
      config['feature_path'] = path
      overwrite_yaml
    end

    def helper_path=(path)
      config['helper_path'] = path
      overwrite_yaml
    end

    def url=(url)
      config['url'] = url
      overwrite_yaml
    end

    def platform=(platform)
      config['platform'] = platform
      overwrite_yaml
    end

    def browser_options=(*opts)
      config['browser_options'] = opts.flatten
      overwrite_yaml
    end

    def delete_browser_options
      config.delete('browser_options')
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

    def download_builds(build_type)
      case build_type
      when 'android'
        download_android_build
      when 'ios'
        download_ios_build
      else
        download_android_build
        download_ios_build
      end
    end

    private

    def overwrite_yaml
      File.open(@path, 'w') { |file| YAML.dump(config, file) }
    end

    def download_android_build
      download_build('Android-MyDemoAppRN.1.3.0.build-244.apk',
                     'https://github.com/saucelabs/my-demo-app-rn/releases/download/v1.3.0/Android-MyDemoAppRN.1.3.0.build-244.apk')
    end

    def download_ios_build
      download_build('iOS-Simulator-MyRNDemoApp.1.3.0-162.zip',
                     'https://github.com/saucelabs/my-demo-app-rn/releases/download/v1.3.0/iOS-Simulator-MyRNDemoApp.1.3.0-162.zip')
    end

    def download_build(name, url)
      response = Faraday.get(url)
      build_url = Faraday.get(response.headers['location'])

      File.open(name, 'wb') do |file|
        file.write(build_url.body)
      end
    end

    def config
      @config ||= File.exist?(@path) ? YAML.load_file(@path) : nil
    end
  end
end
