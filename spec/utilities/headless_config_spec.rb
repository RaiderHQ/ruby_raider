# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require 'erb'

RSpec.describe 'Headless config support in driver templates' do
  let(:tmp_dir) { 'tmp_headless_test' }

  before do
    FileUtils.mkdir_p(tmp_dir)
    Dir.chdir(tmp_dir)
  end

  after do
    Dir.chdir('..')
    FileUtils.rm_rf(tmp_dir)
  end

  describe 'selenium driver template' do
    it 'checks config headless key' do
      content = File.read(File.expand_path('../../lib/generators/templates/helpers/partials/selenium_driver.tt',
                                           __dir__))
      expect(content).to include("@config['headless']")
    end

    it 'checks ENV HEADLESS' do
      content = File.read(File.expand_path('../../lib/generators/templates/helpers/partials/selenium_driver.tt',
                                           __dir__))
      expect(content).to include("ENV['HEADLESS']")
    end
  end

  describe 'browser helper template (watir)' do
    it 'checks config headless key' do
      content = File.read(File.expand_path('../../lib/generators/templates/helpers/browser_helper.tt', __dir__))
      expect(content).to include("config['headless']")
    end
  end

  describe 'headless via config.yml' do
    it 'config key is used when YAML has headless: true' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', <<~YAML)
        browser: chrome
        headless: true
        browser_arguments:
          chrome:
            - no-sandbox
      YAML

      config = YAML.load_file('config/config.yml')
      args = config['browser_arguments'][config['browser']]

      # Simulate the template logic
      args += ['--headless'] if (ENV['HEADLESS'] || config['headless']) && !args.include?('--headless')

      expect(args).to include('--headless')
    end

    it 'config key is not used when headless: false' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', <<~YAML)
        browser: chrome
        headless: false
        browser_arguments:
          chrome:
            - no-sandbox
      YAML

      config = YAML.load_file('config/config.yml')
      args = config['browser_arguments'][config['browser']]

      # Temporarily clear ENV to isolate config behavior
      original_env = ENV.delete('HEADLESS')
      args += ['--headless'] if (ENV['HEADLESS'] || config['headless']) && !args.include?('--headless')
      ENV['HEADLESS'] = original_env if original_env

      expect(args).not_to include('--headless')
    end
  end
end
