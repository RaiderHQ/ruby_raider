require 'dotenv'
require 'fileutils'
require 'pathname'
require 'yaml'
require_relative '../lib/generators/common_generator'
require_relative '../lib/commands/utility_commands'
require_relative '../lib/scaffolding/scaffolding'
require_relative 'spec_helper'

describe UtilityCommands do
  let(:utility) { described_class }
  let(:name) { 'test' }

  orig_dir = Dir.pwd

  after do
    Dir.chdir orig_dir
  end

  context 'with a spec folder' do
    let(:new_path) { 'test_folder' }

    path = "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"

    before do
      Dir.chdir path
    end

    it 'changes the path for specs' do
      utility.new.invoke(:path, nil, %W[#{path} -s])
      config = YAML.load_file('config/config.yml')
      expect(config['spec_path']).to eql path
    end

    it 'updates the url' do
      utility.new.invoke(:url, nil, %w[test.com])
      config = YAML.load_file('config/config.yml')
      expect(config['url']).to eql 'test.com'
    end

    it 'updates the browser' do
      utility.new.invoke(:browser, nil, %w[:firefox])
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql ':firefox'
    end

    it 'updates the browser options' do
      utility.new.invoke(:browser, nil, %w[:firefox --opts headless start-maximized start-fullscreen])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to eql %w[headless start-maximized start-fullscreen]
    end
  end

  context 'with a features folder' do
    let(:new_path) { 'test_folder' }

    path = "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"

    before do
      Dir.chdir path
    end

    it 'changes the path for pages' do
      utility.new.invoke(:path, nil, %W[#{path}])
      config = YAML.load_file('config/config.yml')
      expect(config['page_path']).to eql path
    end

    it 'changes the path for features' do
      utility.new.invoke(:path, nil, %W[#{path} -f])
      config = YAML.load_file('config/config.yml')
      expect(config['feature_path']).to eql path
    end

    it 'updates only the browser options' do
      utility.new.invoke(:browser, nil, %w[:firefox --opts headless])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to eql %w[headless]
    end

    it 'deletes the browser options when passed with the delete parameter' do
      utility.new.invoke(:browser, nil, %w[:firefox --opts headless --delete])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to be_nil
    end

    it 'deletes the browser options' do
      utility.new.invoke(:browser, nil, %w[:firefox --opts headless])
      utility.new.invoke(:browser, nil, %w[--delete])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to be_nil
    end
  end

  context 'with open ai' do
    Dotenv.load

    after do
      FileUtils.rm_rf('joke.txt')
    end

    it 'creates a file using open ai' do
      utility.new.invoke(:open_ai, nil, ['tell me a joke', '--path', 'joke.txt'])
      expect(File).to be_size('joke.txt')
    end

    it 'edits an existing file using open ai' do
      FileUtils.touch('joke.txt')
      utility.new.invoke(:open_ai, nil, ['tell me a better joke', '--edit', 'joke.txt'])
    end
  end
end
