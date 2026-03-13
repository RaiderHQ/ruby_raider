# frozen_string_literal: true

require 'yaml'
require_relative 'content_helper'

describe 'Config file content' do
  shared_examples 'valid web config' do |project_name|
    subject(:config_content) { read_generated(project_name, 'config/config.yml') }

    let(:config) { YAML.safe_load(config_content, permitted_classes: [Symbol]) }

    it 'has browser key' do
      expect(config).to have_key('browser')
      expect(config['browser']).to eq('chrome')
    end

    it 'has url key' do
      expect(config).to have_key('url')
      expect(config['url']).to include('http')
    end

    it 'has browser_arguments section' do
      expect(config_content).to include('browser_arguments:')
      expect(config_content).to include('chrome:')
      expect(config_content).to include('firefox:')
    end
  end

  shared_examples 'selenium config with timeout' do |project_name|
    subject(:config_content) { read_generated(project_name, 'config/config.yml') }

    let(:config) { YAML.safe_load(config_content, permitted_classes: [Symbol]) }

    it 'has timeout key' do
      expect(config).to have_key('timeout')
      expect(config['timeout']).to eq(10)
    end

    it 'has viewport section' do
      expect(config).to have_key('viewport')
      expect(config['viewport']['width']).to eq(1920)
      expect(config['viewport']['height']).to eq(1080)
    end
  end

  shared_examples 'config without driver_options' do |project_name|
    subject(:config_content) { read_generated(project_name, 'config/config.yml') }

    it 'does not have driver_options section' do
      expect(config_content).not_to include('driver_options:')
    end
  end

  shared_examples 'config with video section' do |project_name|
    subject(:config_content) { read_generated(project_name, 'config/config.yml') }

    let(:config) { YAML.safe_load(config_content, permitted_classes: [Symbol]) }

    it 'has video section' do
      expect(config).to have_key('video')
    end

    it 'has video enabled key defaulting to false' do
      expect(config['video']['enabled']).to be false
    end

    it 'has video strategy key' do
      expect(config['video']['strategy']).to eq('auto')
    end
  end

  shared_examples 'config with debug section' do |project_name|
    subject(:config_content) { read_generated(project_name, 'config/config.yml') }

    let(:config) { YAML.safe_load(config_content, permitted_classes: [Symbol]) }

    it 'has debug section' do
      expect(config).to have_key('debug')
    end

    it 'has debug enabled key defaulting to false' do
      expect(config['debug']['enabled']).to be false
    end

    it 'has debug console_logs key' do
      expect(config['debug']['console_logs']).to be true
    end

    it 'has debug action_logging key' do
      expect(config['debug']['action_logging']).to be true
    end

    it 'has debug network_logging key' do
      expect(config['debug']['network_logging']).to be true
    end

    it 'has debug log_dir key' do
      expect(config['debug']['log_dir']).to eq('debug_logs')
    end
  end

  # --- Web config per automation ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid web config', name
    include_examples 'selenium config with timeout', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid web config', name
    include_examples 'config without driver_options', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  context 'with rspec and capybara' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CAPYBARA}"
    include_examples 'valid web config', name
    include_examples 'config without driver_options', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid web config', name
    include_examples 'selenium config with timeout', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  context 'with minitest and selenium' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid web config', name
    include_examples 'selenium config with timeout', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  context 'with minitest and watir' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}"
    include_examples 'valid web config', name
    include_examples 'config without driver_options', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  context 'with minitest and capybara' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}"
    include_examples 'valid web config', name
    include_examples 'config without driver_options', name
    include_examples 'config with video section', name
    include_examples 'config with debug section', name
  end

  # --- Mobile config ---

  context 'with rspec and appium android' do
    subject(:caps) { read_generated("#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}", 'config/capabilities.yml') }

    it 'contains expected configuration keys' do
      expect(caps).to include('platformName')
      expect(caps).to include('automationName')
      expect(caps).to include('deviceName')
    end

    it 'has platform capabilities' do
      expect(caps).to match(/platformName/i)
    end
  end

end
