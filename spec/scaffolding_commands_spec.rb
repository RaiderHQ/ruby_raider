require 'pathname'
require 'yaml'
require_relative '../lib/generators/common_generator'
require_relative '../lib/commands/scaffolding_commands'
require_relative 'spec_helper'

describe ScaffoldingCommands do
  let(:scaffold) { described_class }
  let(:name) { 'test' }

  after(:all) do
    folders = %w[test config page_objects features]
    folders.each do |folder|
      FileUtils.rm_rf(folder)
    end
    FileUtils.rm('spec/test_spec.rb') if Pathname.new('spec/test_spec.rb').exist?
  end

  context 'with a spec folder' do
    before(:all) do
      described_class.new.invoke(:config)
    end

    it 'scaffolds for rspec creating a spec' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("spec/#{name}_spec.rb")).to be_file
    end

    it 'scaffolds for rspec creating a page' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to be_file
    end
  end

  context 'with a features folder' do
    it 'scaffolds for cucumber creating a feature' do
      FileUtils.mkdir 'features'
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("features/#{name}.feature")).to be_file
    end

    it 'scaffolds for cucumber creating a page' do
      FileUtils.mkdir 'features'
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to be_file
    end
  end

  context 'with path from config file' do
    before(:all) do
      described_class.new.invoke(:config)
    end

    after(:all) do
      folders = %w[test config page_objects features helpers]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
      FileUtils.rm('spec/test_spec.rb') if Pathname.new('spec/test_spec.rb').exist?
    end

    it 'creates a page' do
      scaffold.new.invoke(:page, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to be_file
    end

    it 'creates a feature' do
      scaffold.new.invoke(:feature, nil, %W[#{name}])
      expect(Pathname.new("features/#{name}.feature")).to be_file
    end

    it 'creates a spec' do
      scaffold.new.invoke(:spec, nil, %W[#{name}])
      expect(Pathname.new("spec/#{name}_spec.rb")).to be_file
    end

    it 'creates a helper' do
      scaffold.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("helpers/#{name}_helper.rb")).to be_file
    end

    it 'deletes a page' do
      scaffold.new.invoke(:page, nil, %W[#{name}])
      scaffold.new.invoke(:page, nil, %W[#{name} --delete])
      expect(Pathname.new("page_objects/pages/#{name}_page.rb")).not_to be_file
    end

    it 'deletes a feature' do
      scaffold.new.invoke(:feature, nil, %W[#{name}])
      scaffold.new.invoke(:feature, nil, %W[#{name} --delete])
      expect(Pathname.new("features/#{name}.feature")).not_to be_file
    end

    it 'deletes a spec' do
      scaffold.new.invoke(:spec, nil, %W[#{name}])
      scaffold.new.invoke(:spec, nil, %W[#{name} --delete])
      expect(Pathname.new("spec/#{name}_spec.rb")).not_to be_file
    end

    it 'deletes a helper' do
      scaffold.new.invoke(:helper, nil, %W[#{name}])
      scaffold.new.invoke(:helper, nil, %W[#{name} --delete])
      expect(Pathname.new("helpers/#{name}_helper.rb")).not_to be_file
    end
  end

  context 'with path option' do
    let(:path) { 'test_folder' }

    after do
      FileUtils.rm_rf(path)
    end

    it 'creates a page' do
      scaffold.new.invoke(:page, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}_page.rb")).to be_file
    end

    it 'creates a feature' do
      scaffold.new.invoke(:feature, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}.feature")).to be_file
    end

    it 'creates a spec' do
      scaffold.new.invoke(:spec, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}_spec.rb")).to be_file
    end

    it 'creates a helper' do
      scaffold.new.invoke(:helper, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}_helper.rb")).to be_file
    end
  end

  context 'without default path' do
    let(:path) { 'test_folder' }

    before(:all) do
      described_class.new.invoke(:config)
    end

    after(:all) do
      folders = %w[test_folder test config]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
    end

    it 'changes the path for pages' do
      scaffold.new.invoke(:path, nil, %W[#{path}])
      config = YAML.load_file('config/config.yml')
      expect(config['page_path']).to eql path
    end

    it 'changes the path for features' do
      scaffold.new.invoke(:path, nil, %W[#{path} -f])
      config = YAML.load_file('config/config.yml')
      expect(config['feature_path']).to eql path
    end

    it 'changes the path for specs' do
      scaffold.new.invoke(:path, nil, %W[#{path} -s])
      config = YAML.load_file('config/config.yml')
      expect(config['spec_path']).to eql path
    end

    it 'creates page' do
      scaffold.new.invoke(:path, nil, %W[#{path}])
      scaffold.new.invoke(:page, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}_page.rb")).to be_file
    end

    it 'creates feature' do
      scaffold.new.invoke(:path, nil, %W[#{path} -f])
      scaffold.new.invoke(:feature, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}.feature")).to be_file
    end

    it 'creates spec' do
      scaffold.new.invoke(:path, nil, %W[#{path} -s])
      scaffold.new.invoke(:spec, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}_spec.rb")).to be_file
    end

    it 'creates a helper' do
      scaffold.new.invoke(:path, nil, %W[#{path} -h])
      scaffold.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}_helper.rb")).to be_file
    end
  end

  context 'updates the config file' do
    before(:all) do
      CommonGenerator.new(%w[rspec selenium test]).invoke(:generate_config_file)
      FileUtils.cp_lr('test/config', './')
    end

    after(:all) do
      folders = %w[test config]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
    end

    it 'updates the url' do
      scaffold.new.invoke(:url, nil, %w[test.com])
      config = YAML.load_file('config/config.yml')
      expect(config['url']).to eql 'test.com'
    end

    it 'updates the browser' do
      scaffold.new.invoke(:browser, nil, %w[:firefox])
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql ':firefox'
    end

    it 'updates the browser options' do
      scaffold.new.invoke(:browser, nil, %w[:firefox --opts headless start-maximized start-fullscreen])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to eql %w[headless start-maximized start-fullscreen]
    end

    it 'updates only the browser options' do
      scaffold.new.invoke(:browser, nil, %w[:firefox --opts headless])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to eql %w[headless]
    end

    it 'deletes the browser options when passed with the delete parameter' do
      scaffold.new.invoke(:browser, nil, %w[:firefox --opts headless --delete])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to be_nil
    end

    it 'deletes the browser options' do
      scaffold.new.invoke(:browser, nil, %w[:firefox --opts headless])
      scaffold.new.invoke(:browser, nil, %w[--delete])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to be_nil
    end
  end
end
