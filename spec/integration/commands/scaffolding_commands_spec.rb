require 'pathname'
require 'yaml'
require_relative '../../../lib/generators/common_generator'
require_relative '../../../lib/commands/scaffolding_commands'
require_relative '../../../lib/scaffolding/scaffolding'
require_relative '../spec_helper'

describe ScaffoldingCommands do
  let(:scaffold) { described_class }
  let(:name) { 'test' }

  orig_dir = Dir.pwd

  after do
    Dir.chdir orig_dir
  end

  context 'with a spec folder' do
    let(:new_path) { 'test_folder' }

    path = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"

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

    it 'creates a helper' do
      scaffold.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("helpers/#{name}_helper.rb")).to be_file
    end

    it 'creates a helper with a path' do
      scaffold.new.invoke(:helper, nil, %W[#{name} --path #{new_path}])
      expect(Pathname.new("#{new_path}/#{name}_helper.rb")).to be_file
    end
  end

  describe 'selenium examples' do
    let(:tmp_dir) { 'tmp_scaffold_examples_test' }

    def scaffold_in_project(kind)
      FileUtils.mkdir_p(tmp_dir)
      File.write("#{tmp_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
      Dir.chdir(tmp_dir) { scaffold.new.invoke(kind, nil, %w[foo]) }
    end

    after do
      Dir.chdir orig_dir
      FileUtils.rm_rf(tmp_dir)
    end

    it 'shows the by_role example in a page' do
      scaffold_in_project(:page)
      expect(File.read("#{tmp_dir}/page_objects/pages/foo.rb"))
        .to include("# Example: def submit_button = driver.find_element(by_role('button', name: 'Submit'))")
    end

    it 'shows the component example in a component' do
      scaffold_in_project(:component)
      expect(File.read("#{tmp_dir}/page_objects/components/foo.rb")).to include("# Example: component.find_element(css: '.selector').click")
    end
  end
end
