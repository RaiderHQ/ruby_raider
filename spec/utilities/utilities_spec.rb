# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative '../../lib/utilities/utilities'

RSpec.describe Utilities do
  let(:tmp_dir) { 'tmp_utilities_test' }
  let(:config_path) { 'config/config.yml' }

  before do
    FileUtils.mkdir_p(tmp_dir)
    Dir.chdir(tmp_dir)
    FileUtils.mkdir_p('config')
    File.write(config_path, <<~YAML)
      browser: chrome
      url: 'http://localhost:3000'
      timeout: 10
      viewport:
        width: 1920
        height: 1080
      browser_arguments:
        chrome:
          - no-sandbox
          - disable-dev-shm-usage
        firefox:
          - acceptInsecureCerts
    YAML
    # Reset cached config between tests
    described_class.instance_variable_set(:@config, nil)
  end

  after do
    Dir.chdir('..')
    FileUtils.rm_rf(tmp_dir)
  end

  describe '.browser_options=' do
    it 'writes to browser_arguments for the current browser' do
      described_class.browser_options = %w[no-sandbox headless]
      config = YAML.load_file(config_path)
      expect(config['browser_arguments']['chrome']).to eq(%w[no-sandbox headless])
    end

    it 'writes to the correct browser key when browser is firefox' do
      described_class.browser = 'firefox'
      described_class.instance_variable_set(:@config, nil)
      described_class.browser_options = %w[headless]
      config = YAML.load_file(config_path)
      expect(config['browser_arguments']['firefox']).to eq(%w[headless])
    end

    it 'preserves other browser arguments' do
      described_class.browser_options = %w[headless]
      config = YAML.load_file(config_path)
      expect(config['browser_arguments']['firefox']).to eq(%w[acceptInsecureCerts])
    end
  end

  describe '.delete_browser_options' do
    it 'removes browser_arguments for the current browser' do
      described_class.delete_browser_options
      config = YAML.load_file(config_path)
      expect(config['browser_arguments']['chrome']).to be_nil
    end

    it 'preserves other browser arguments' do
      described_class.delete_browser_options
      config = YAML.load_file(config_path)
      expect(config['browser_arguments']['firefox']).to eq(%w[acceptInsecureCerts])
    end
  end

  describe '.headless=' do
    it 'sets headless to true' do
      described_class.headless = true
      config = YAML.load_file(config_path)
      expect(config['headless']).to be true
    end

    it 'sets headless to false' do
      described_class.headless = true
      described_class.instance_variable_set(:@config, nil)
      described_class.headless = false
      config = YAML.load_file(config_path)
      expect(config['headless']).to be false
    end
  end

  describe '.viewport=' do
    it 'sets viewport dimensions' do
      described_class.viewport = '375x812'
      config = YAML.load_file(config_path)
      expect(config['viewport']).to eq({ 'width' => 375, 'height' => 812 })
    end
  end

  describe '.browser_options= writes to browser_arguments not browser_options' do
    it 'does not create a browser_options key' do
      described_class.browser_options = %w[headless]
      config = YAML.load_file(config_path)
      expect(config).not_to have_key('browser_options')
    end
  end
end
