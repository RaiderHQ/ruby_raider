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

  # --- Web config per automation ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid web config', name
    include_examples 'selenium config with timeout', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid web config', name
    include_examples 'config without driver_options', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid web config', name
    include_examples 'selenium config with timeout', name
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
