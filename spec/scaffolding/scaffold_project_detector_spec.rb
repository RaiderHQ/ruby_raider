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

    it 'detects rspec framework' do
      expect(described_class.detect_framework).to eq('rspec')
    end

    it 'reports selenium?' do
      expect(described_class.selenium?).to be true
    end

    it 'reports not capybara?' do
      expect(described_class.capybara?).to be false
    end
  end

  context 'with capybara project' do
    before do
      File.write('Gemfile', "gem 'capybara'\ngem 'cucumber'\n")
      FileUtils.mkdir_p('features')
    end

    it 'detects capybara automation' do
      expect(described_class.detect_automation).to eq('capybara')
    end

    it 'detects cucumber framework' do
      expect(described_class.detect_framework).to eq('cucumber')
    end

    it 'reports capybara?' do
      expect(described_class.capybara?).to be true
    end
  end

  context 'with watir project' do
    before do
      File.write('Gemfile', "gem 'watir'\ngem 'minitest'\n")
      FileUtils.mkdir_p('test')
    end

    it 'detects watir automation' do
      expect(described_class.detect_automation).to eq('watir')
    end

    it 'detects minitest framework' do
      expect(described_class.detect_framework).to eq('minitest')
    end

    it 'reports watir?' do
      expect(described_class.watir?).to be true
    end
  end

  context 'with no Gemfile' do
    it 'defaults to selenium' do
      expect(described_class.detect_automation).to eq('selenium')
    end

    it 'defaults to rspec' do
      expect(described_class.detect_framework).to eq('rspec')
    end
  end

  describe '.detect' do
    before do
      File.write('Gemfile', "gem 'selenium-webdriver'\ngem 'rspec'\n")
      FileUtils.mkdir_p('spec')
    end

    it 'returns full detection hash' do
      result = described_class.detect
      expect(result[:automation]).to eq('selenium')
      expect(result[:framework]).to eq('rspec')
      expect(result[:has_spec]).to be true
      expect(result[:has_features]).to be false
    end
  end
end
