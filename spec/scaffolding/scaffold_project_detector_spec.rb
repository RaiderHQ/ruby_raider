# frozen_string_literal: true

require 'fileutils'
require_relative '../../lib/scaffolding/project_detector'

RSpec.describe ScaffoldProjectDetector do
  let(:tmp_dir) { 'tmp_project_detector_test' }

  before do
    FileUtils.mkdir_p(tmp_dir)
    Dir.chdir(tmp_dir)
  end

  after do
    Dir.chdir('..')
    FileUtils.rm_rf(tmp_dir)
  end

  context 'with selenium project' do
    before do
      File.write('Gemfile', "gem 'rspec'\ngem 'selenium-webdriver'\n")
      FileUtils.mkdir_p('spec')
    end

    it 'detects selenium automation' do
      expect(described_class.detect_automation).to eq('selenium')
    end

    it 'reports selenium?' do
      expect(described_class.selenium?).to be true
    end
  end

  context 'with no Gemfile' do
    it 'defaults to selenium' do
      expect(described_class.detect_automation).to eq('selenium')
    end
  end

  describe '.validate_project' do
    it 'warns when Gemfile is missing' do
      warnings = described_class.validate_project
      expect(warnings).to include(match(/Gemfile not found/))
    end

    it 'warns when config/config.yml is missing' do
      File.write('Gemfile', "gem 'rspec'\n")
      warnings = described_class.validate_project
      expect(warnings).to include(match(/config\.yml not found/))
    end

    it 'returns no warnings for valid project' do
      File.write('Gemfile', "gem 'rspec'\n")
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "browser: chrome\n")
      expect(described_class.validate_project).to be_empty
    end
  end

  it 'no longer detects a wait helper' do
    expect(described_class).not_to respond_to(:wait_helper?)
  end

  describe '.config' do
    it 'returns empty hash when config missing' do
      expect(described_class.config).to eq({})
    end

    it 'parses valid config' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "browser: chrome\nurl: http://localhost\n")
      expect(described_class.config).to eq({ 'browser' => 'chrome', 'url' => 'http://localhost' })
    end

    it 'raises Error on malformed YAML' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "browser: chrome\n  bad:\nindent")
      expect { described_class.config }.to raise_error(ScaffoldProjectDetector::Error, /invalid YAML syntax/)
    end
  end

  describe '.detect' do
    before do
      File.write('Gemfile', "gem 'selenium-webdriver'\ngem 'rspec'\n")
      FileUtils.mkdir_p('spec')
    end

    it 'returns the automation and whether there is a spec folder, and nothing else' do
      expect(described_class.detect).to eq(automation: 'selenium', has_spec: true)
    end
  end
end
