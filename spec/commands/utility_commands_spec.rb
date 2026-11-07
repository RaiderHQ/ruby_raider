# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative '../../lib/ruby_raider'

RSpec.describe UtilityCommands do
  let(:tmp_dir) { 'tmp_utility_commands_test' }

  before do
    FileUtils.mkdir_p("#{tmp_dir}/config")
    Dir.chdir(tmp_dir)
    File.write('config/config.yml', "browser: chrome\ntimeout: 10\n")
    Utilities.instance_variable_set(:@config, nil)
  end

  after do
    Dir.chdir('..')
    FileUtils.rm_rf(tmp_dir)
    Utilities.instance_variable_set(:@config, nil)
  end

  describe 'strict' do
    it 'writes strict: false for off' do
      described_class.new.invoke(:strict, nil, %w[off])
      expect(YAML.load_file('config/config.yml')['strict']).to be false
    end

    it 'writes strict: true for on' do
      described_class.new.invoke(:strict, nil, %w[on])
      expect(YAML.load_file('config/config.yml')['strict']).to be true
    end
  end

  describe 'actionability' do
    it 'writes actionability: true for on' do
      described_class.new.invoke(:actionability, nil, %w[on])
      expect(YAML.load_file('config/config.yml')['actionability']).to be true
    end

    it 'writes actionability: false for off' do
      described_class.new.invoke(:actionability, nil, %w[off])
      expect(YAML.load_file('config/config.yml')['actionability']).to be false
    end
  end

  describe 'help' do
    it 'lists both toggles' do
      expect { described_class.start(%w[help]) }
        .to output(%r{actionability \[on/off\].*strict \[on/off\]}m).to_stdout
    end
  end
end
