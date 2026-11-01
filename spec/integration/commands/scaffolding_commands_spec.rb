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
  end

  context 'with a features folder' do
    let(:new_path) { 'test_folder' }

    path = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"

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

    it 'scaffolds for cucumber creating a steps definition' do
      scaffold.new.invoke(:scaffold, nil, %W[#{name}])
      expect(Pathname.new("features/step_definitions/#{name}_steps.rb")).to be_file
    end

    it 'creates a helper' do
      scaffold.new.invoke(:helper, nil, %W[#{name}])
      expect(Pathname.new("helpers/#{name}_helper.rb")).to be_file
    end

    it 'creates a steps definition' do
      scaffold.new.invoke(:steps, nil, %W[#{name}])
      expect(Pathname.new("features/step_definitions/#{name}_steps.rb")).to be_file
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

  describe 'waiting examples' do
    let(:tmp_dir) { 'tmp_scaffold_wait_helper_test' }
    let(:selenium_example) { "driver.find_element(id: 'element_id')" }
    let(:waiting_example) { "click({ id: 'element_id' })" }

    def scaffold_in_project(gem_name, kind, wait_helper:)
      FileUtils.mkdir_p("#{tmp_dir}/helpers")
      File.write("#{tmp_dir}/Gemfile", "gem 'rspec'\ngem '#{gem_name}'\n")
      File.write("#{tmp_dir}/helpers/wait_helper.rb", '') if wait_helper
      Dir.chdir(tmp_dir) { scaffold.new.invoke(kind, nil, %w[foo]) }
    end

    after do
      Dir.chdir orig_dir
      FileUtils.rm_rf(tmp_dir)
    end

    it 'shows the waiting example in a page when the project has the wait helper' do
      scaffold_in_project('selenium-webdriver', :page, wait_helper: true)
      content = File.read("#{tmp_dir}/page_objects/pages/foo.rb")
      expect(content).to include(waiting_example)
      expect(content).not_to include(selenium_example)
    end

    it 'keeps the driver example in a page without the wait helper' do
      scaffold_in_project('selenium-webdriver', :page, wait_helper: false)
      content = File.read("#{tmp_dir}/page_objects/pages/foo.rb")
      expect(content).to include(selenium_example)
      expect(content).not_to include(waiting_example)
    end

    it 'shows the waiting example in a component when the project has the wait helper' do
      scaffold_in_project('selenium-webdriver', :component, wait_helper: true)
      expect(File.read("#{tmp_dir}/page_objects/components/foo.rb")).to include("click({ css: '.selector' })")
    end

    it 'keeps the driver example in a component without the wait helper' do
      scaffold_in_project('selenium-webdriver', :component, wait_helper: false)
      expect(File.read("#{tmp_dir}/page_objects/components/foo.rb")).to include("driver.find_element(css: '.selector')")
    end

    it 'leaves Watir output unchanged even with a wait helper present' do
      scaffold_in_project('watir', :page, wait_helper: true)
      content = File.read("#{tmp_dir}/page_objects/pages/foo.rb")
      expect(content).to include("browser.text_field(id: 'element_id')")
      expect(content).not_to include(waiting_example)
    end
  end
end
