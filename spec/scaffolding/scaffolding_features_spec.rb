# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require_relative '../../lib/commands/scaffolding_commands'
require_relative '../../lib/scaffolding/scaffolding'

RSpec.describe 'Scaffolding features' do
  let(:scaffold) { ScaffoldingCommands }
  let(:tmp_dir) { 'tmp_scaffold_features_test' }

  before do
    FileUtils.mkdir_p("#{tmp_dir}/page_objects/pages")
    FileUtils.mkdir_p("#{tmp_dir}/page_objects/abstract")
    FileUtils.mkdir_p("#{tmp_dir}/page_objects/components")
    FileUtils.mkdir_p("#{tmp_dir}/spec")
    FileUtils.mkdir_p("#{tmp_dir}/helpers")
    FileUtils.mkdir_p("#{tmp_dir}/config")
    FileUtils.mkdir_p("#{tmp_dir}/models/data")

    File.write("#{tmp_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
    File.write("#{tmp_dir}/config/config.yml", "browser: chrome\nurl: http://localhost:3000\n")
    File.write("#{tmp_dir}/page_objects/abstract/page.rb", "class Page; end\n")
    File.write("#{tmp_dir}/page_objects/abstract/component.rb", "class Component; end\n")

    Dir.chdir(tmp_dir)
  end

  after do
    Dir.chdir('..')
    FileUtils.rm_rf(tmp_dir)
  end

  # --- Feature 7: Better name handling ---

  describe 'name normalization' do
    it 'strips _page suffix from page names' do
      scaffold.new.invoke(:page, nil, %w[login_page])
      expect(Pathname.new('page_objects/pages/login.rb')).to be_file
    end

    it 'handles CamelCase input' do
      scaffold.new.invoke(:page, nil, %w[UserProfile])
      expect(Pathname.new('page_objects/pages/user_profile.rb')).to be_file
    end

    it 'handles CamelCase with Page suffix' do
      scaffold.new.invoke(:page, nil, %w[LoginPage])
      expect(Pathname.new('page_objects/pages/login.rb')).to be_file
    end
  end

  # --- Feature 8: Component scaffolding ---

  describe 'component scaffolding' do
    it 'creates a component file' do
      scaffold.new.invoke(:component, nil, %w[sidebar])
      expect(Pathname.new('page_objects/components/sidebar.rb')).to be_file
    end

    it 'component inherits from Component' do
      scaffold.new.invoke(:component, nil, %w[sidebar])
      content = File.read('page_objects/components/sidebar.rb')
      expect(content).to include('class Sidebar < Component')
    end

    it 'component has frozen_string_literal' do
      scaffold.new.invoke(:component, nil, %w[sidebar])
      content = File.read('page_objects/components/sidebar.rb')
      expect(content).to include('# frozen_string_literal: true')
    end
  end

  # --- Feature 10: Config-aware templates ---

  describe 'config-aware templates' do
    it 'page object includes url method when config has url' do
      scaffold.new.invoke(:page, nil, %w[checkout])
      content = File.read('page_objects/pages/checkout.rb')
      expect(content).to include('def url(_page)')
    end

    it 'page object includes selenium-specific comments' do
      scaffold.new.invoke(:page, nil, %w[checkout])
      content = File.read('page_objects/pages/checkout.rb')
      expect(content).to include('driver.find_element')
    end

    it 'spec includes let for page with driver' do
      scaffold.new.invoke(:spec, nil, %w[checkout])
      content = File.read('spec/checkout_page_spec.rb')
      expect(content).to include('CheckoutPage.new(driver)')
    end
  end

  # --- Feature 1: Batch scaffold ---

  describe 'batch scaffolding' do
    it 'generates multiple scaffolds' do
      scaffold.new.invoke(:scaffold, nil, %w[login dashboard])
      expect(Pathname.new('page_objects/pages/login.rb')).to be_file
      expect(Pathname.new('page_objects/pages/dashboard.rb')).to be_file
      expect(Pathname.new('spec/login_page_spec.rb')).to be_file
      expect(Pathname.new('spec/dashboard_page_spec.rb')).to be_file
    end
  end

end
