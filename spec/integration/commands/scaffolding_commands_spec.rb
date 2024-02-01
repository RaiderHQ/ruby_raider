require 'dotenv'
require 'pathname'
require 'yaml'
require_relative '../../../lib/generators/common_generator'
require_relative '../../../lib/commands/scaffolding_commands'
require_relative '../../../lib/scaffolding/scaffolding'
require_relative '../../spec_helper'

describe ScaffoldingCommands do
  let(:scaffold) { described_class }
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

    it 'scaffolds for rspec creating a spec' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("spec/#{name}_page_spec.rb")).to be_file
    end

    it 'scaffolds for rspec creating a page' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}.rb")).to be_file
    end

    it 'deletes a spec' do
      scaffold.new.invoke(:spec, nil, %w[login --delete])
      expect(Pathname.new('spec/login_spec.rb')).not_to be_file
    end

    it 'deletes a helper' do
      scaffold.new.invoke(:helper, nil, %w[driver --delete])
      expect(Pathname.new('helpers/driver_helper.rb')).not_to be_file
    end

    it 'creates a page' do
      scaffold.new.invoke(:page, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}.rb")).to be_file
    end

    it 'creates a page with a path' do
      scaffold.new.invoke(:page, nil, %W[#{name} --path #{new_path}])
      expect(Pathname.new("#{new_path}/#{name}_page.rb")).to be_file
    end

    it 'creates a spec' do
      scaffold.new.invoke(:spec, nil, %W[#{name} --path #{new_path}])
      expect(Pathname.new("#{new_path}/#{name}_spec.rb")).to be_file
    end
  end

  context 'with a features folder' do
    let(:new_path) { 'test_folder' }

    path = "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"

    before do
      Dir.chdir path
    end

    it 'scaffolds for cucumber creating a feature' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("features/#{name}.feature")).to be_file
    end

    it 'scaffolds for cucumber creating a page' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("page_objects/pages/#{name}.rb")).to be_file
    end

    it 'creates a helper' do
      scaffold.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("helpers/#{name}_helper.rb")).to be_file
    end

    it 'deletes a page' do
      scaffold.new.invoke(:page, nil, %w[login --delete])
      expect(Pathname.new('page_objects/pages/login_page.rb')).not_to be_file
    end

    it 'deletes a feature' do
      scaffold.new.invoke(:feature, nil, %w[login --delete])
      expect(Pathname.new('features/login.feature')).not_to be_file
    end

    it 'creates a feature' do
      scaffold.new.invoke(:feature, nil, %W[#{name} --path #{new_path}])
      expect(Pathname.new("#{new_path}/#{name}.feature")).to be_file
    end

    it 'creates a helper with a path' do
      scaffold.new.invoke(:helper, nil, %W[#{name} --path #{new_path}])
      expect(Pathname.new("#{new_path}/#{name}_helper.rb")).to be_file
    end
  end
end
