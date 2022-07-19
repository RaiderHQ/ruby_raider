require 'pathname'
require 'yaml'
require_relative 'spec_helper'
require_relative '../lib/ruby_raider.thor'
require_relative '../lib/generators/common_generator'

describe RubyRaider do
  let(:raider) { RubyRaider }
  let(:name) {'test'}

  context 'with path from config file' do
    before(:all) do
      CommonGenerator.new(%w[rspec cucumber test]).invoke(:generate_config_file)
      FileUtils.cp_lr('test/config', './')
    end

    it 'creates a page' do
      raider.new.invoke(:page, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to be_file
    end

    it 'creates a feature' do
      raider.new.invoke(:feature, nil, %W[#{name}])
      expect(Pathname.new("features/#{name}.feature")).to be_file
    end

    it 'creates a spec' do
      raider.new.invoke(:spec, nil, %W[#{name}])
      expect(Pathname.new("spec/#{name}_spec.rb")).to be_file
    end

    it 'creates a helper' do
      raider.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("helpers/#{name}_helper.rb")).to be_file
    end

    it 'deletes a page' do
      raider.new.invoke(:page, nil, %W[#{name}])
      raider.new.invoke(:page, nil, %W[#{name} --delete])
      expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to_not be_file
    end

    it 'deletes a feature' do
      raider.new.invoke(:feature, nil, %W[#{name}])
      raider.new.invoke(:feature, nil, %W[#{name} --delete])
      expect(Pathname.new("features/#{name}.feature")).to_not be_file
    end

    it 'deletes a spec' do
      raider.new.invoke(:spec, nil, %W[#{name}])
      raider.new.invoke(:spec, nil, %W[#{name} --delete])
      expect(Pathname.new("spec/#{name}_spec.rb")).to_not be_file
    end

    it 'deletes a helper' do
      raider.new.invoke(:helper, nil, %W[#{name}])
      raider.new.invoke(:helper, nil, %W[#{name} --delete])
      expect(Pathname.new("helpers/#{name}_helper.rb")).to_not be_file
    end

    after(:all) do
      folders = %w[test config page_objects features helpers]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
      FileUtils.rm('spec/test_spec.rb') if Pathname.new('spec/test_spec.rb').exist?
    end
  end

  context 'with path option' do
    let(:path) { 'test_folder' }

    it 'creates a page' do
      raider.new.invoke(:page, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}_page.rb")).to be_file
    end

    it 'creates a feature' do
      raider.new.invoke(:feature, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}.feature")).to be_file
    end

    it 'creates a spec' do
      raider.new.invoke(:spec, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}_spec.rb")).to be_file
    end

    it 'creates a helper' do
      raider.new.invoke(:helper, nil, %W[#{name} --path #{path}])
      expect(Pathname.new("#{path}/#{name}_helper.rb")).to be_file
    end

    after(:each) do
      FileUtils.rm_rf(path)
    end
  end

  context 'changes the default path' do
    let(:path) { 'test_folder' }

    before(:all) do
      CommonGenerator.new(%w[rspec cucumber test]).invoke(:generate_config_file)
      FileUtils.cp_lr('test/config', './')
    end

    it 'changes the path for pages' do
      raider.new.invoke(:path, nil, %W[#{path}])
      config = YAML.load_file('config/config.yml')
      expect(config['page_path']).to eql path
    end

    it 'changes the path for features' do
      raider.new.invoke(:path, nil, %W[#{path} -f])
      config = YAML.load_file('config/config.yml')
      expect(config['feature_path']).to eql path
    end

    it 'changes the path for specs' do
      raider.new.invoke(:path, nil, %W[#{path} -s])
      config = YAML.load_file('config/config.yml')
      expect(config['spec_path']).to eql path
    end

    it 'creates page' do
      raider.new.invoke(:path, nil, %W[#{path}])
      raider.new.invoke(:page, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}_page.rb")).to be_file
    end

    it 'creates feature' do
      raider.new.invoke(:path, nil, %W[#{path} -f])
      raider.new.invoke(:feature, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}.feature")).to be_file
    end

    it 'creates spec' do
      raider.new.invoke(:path, nil, %W[#{path} -s])
      raider.new.invoke(:spec, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}_spec.rb")).to be_file
    end

    it 'creates spec' do
      raider.new.invoke(:path, nil, %W[#{path} -h])
      raider.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("#{path}/#{name}_helper.rb")).to be_file
    end

    after(:all) do
      folders = %w[test_folder test config]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
    end
  end

  context 'updates the config file' do
    before(:all) do
      CommonGenerator.new(%w[rspec selenium test]).invoke(:generate_config_file)
      FileUtils.cp_lr('test/config', './')
    end

    it 'updates the url' do
      raider.new.invoke(:url, nil, %W[test.com])
      config = YAML.load_file('config/config.yml')
      expect(config['url']).to eql 'test.com'
    end

    it 'updates the browser' do
      raider.new.invoke(:browser, nil, %W[:firefox])
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql ':firefox'
    end

    it 'updates the browser and the browser options' do
      raider.new.invoke(:browser, nil, %W[:firefox --opts headless:test])
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql ':firefox'
      expect(config['browser_options']).to eql "headless" => "test"
    end

    it 'updates only the browser options' do
      raider.new.invoke(:browser, nil, %W[:firefox --opts headless:test])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to eql "headless" => "test"
    end

    it 'deletes the browser options when passed with the delete parameter' do
      raider.new.invoke(:browser, nil, %W[:firefox --opts headless:test --delete])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to be_nil
    end

    it 'deletes the browser options' do
      raider.new.invoke(:browser, nil, %W[:firefox --opts headless:test])
      raider.new.invoke(:browser, nil, %W[--delete])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_options']).to be_nil
    end

    after(:all) do
      folders = %w[test config]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
    end
  end

  context 'scaffolding' do
    before(:all) do
      CommonGenerator.new(%w[rspec selenium test]).invoke(:generate_config_file)
      FileUtils.cp_lr('test/config', './')
    end

    context 'with a spec folder' do
      it 'scaffolds for rspec' do
        raider.new.invoke(:scaffold, nil, %W[#{name}])
        expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to be_file
        expect(Pathname.new("spec/#{name}_spec.rb")).to be_file
      end
    end

    context 'with a features folder' do
      it 'scaffolds for cucumber' do
        FileUtils.mkdir 'features'
        raider.new.invoke(:scaffold, nil, %W[#{name}])
        expect(Pathname.new("page_objects/pages/#{name}_page.rb")).to be_file
        expect(Pathname.new("features/#{name}.feature")).to be_file
      end
    end

    after(:all) do
      folders = %w[test config page_objects features]
      folders.each do |folder|
        FileUtils.rm_rf(folder)
      end
      FileUtils.rm('spec/test_spec.rb') if Pathname.new('spec/test_spec.rb').exist?
    end
  end
end