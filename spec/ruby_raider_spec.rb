require 'pathname'
require_relative 'spec_helper'
require_relative '../lib/ruby_raider'
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

    after(:all) do
      folders = %w[test config page_objects features]
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

    after(:each) do
      FileUtils.rm_rf(path)
    end
  end
end