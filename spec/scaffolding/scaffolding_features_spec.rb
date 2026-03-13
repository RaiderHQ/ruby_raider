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

  # --- Feature 6: Dry run ---

  describe 'dry run' do
    it 'does not create files with --dry-run' do
      expect {
        scaffold.new.invoke(:page, nil, %w[checkout --dry-run])
      }.to output(/checkout/).to_stdout

      expect(Pathname.new('page_objects/pages/checkout.rb')).not_to be_file
    end

    it 'shows planned file path' do
      expect {
        scaffold.new.invoke(:spec, nil, %w[checkout --dry-run])
      }.to output(/checkout/).to_stdout
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

    it 'deletes a component' do
      scaffold.new.invoke(:component, nil, %w[sidebar])
      scaffold.new.invoke(:component, nil, %w[sidebar --delete])
      expect(Pathname.new('page_objects/components/sidebar.rb')).not_to be_file
    end
  end

  # --- Feature 10: Config-aware templates ---

  describe 'config-aware templates' do
    it 'page object includes url method when config has url' do
      scaffold.new.invoke(:page, nil, %w[checkout])
      content = File.read('page_objects/pages/checkout.rb')
      expect(content).to include("def url(_page)")
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

  # --- Feature 9: Relationships ---

  describe 'relationships (--uses)' do
    before do
      File.write('page_objects/pages/login.rb', "class LoginPage < Page; end\n")
    end

    it 'adds require_relative for dependent pages' do
      scaffold.new.invoke(:page, nil, %w[dashboard --uses login])
      content = File.read('page_objects/pages/dashboard.rb')
      expect(content).to include("require_relative 'login'")
    end

    it 'adds uses to spec as let declarations' do
      scaffold.new.invoke(:spec, nil, %w[dashboard --uses login])
      content = File.read('spec/dashboard_page_spec.rb')
      expect(content).to include('LoginPage')
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

  # --- Feature 1: Selective --with ---

  describe 'selective scaffolding (--with)' do
    it 'generates only selected components' do
      scaffold.new.invoke(:scaffold, nil, %w[checkout --with page])
      expect(Pathname.new('page_objects/pages/checkout.rb')).to be_file
      expect(Pathname.new('spec/checkout_page_spec.rb')).not_to be_file
    end

    it 'generates page and helper with --with' do
      scaffold.new.invoke(:scaffold, nil, %w[checkout --with page helper])
      expect(Pathname.new('page_objects/pages/checkout.rb')).to be_file
      expect(Pathname.new('helpers/checkout_helper.rb')).to be_file
    end

    it 'generates model data with --with model' do
      scaffold.new.invoke(:scaffold, nil, %w[user --with model])
      expect(Pathname.new('models/data/user.yml')).to be_file
    end
  end

  # --- Feature 5: CRUD ---

  describe 'CRUD scaffolding' do
    it 'generates CRUD pages' do
      scaffold.new.invoke(:scaffold, nil, %w[user --crud])
      %w[user_list user_create user_detail user_edit].each do |page|
        expect(Pathname.new("page_objects/pages/#{page}.rb")).to be_file
      end
    end

    it 'generates CRUD specs' do
      scaffold.new.invoke(:scaffold, nil, %w[user --crud])
      %w[user_list user_create user_detail user_edit].each do |page|
        expect(Pathname.new("spec/#{page}_page_spec.rb")).to be_file
      end
    end

    it 'generates model data file' do
      scaffold.new.invoke(:scaffold, nil, %w[user --crud])
      expect(Pathname.new('models/data/user.yml')).to be_file
    end

    it 'model data has expected structure' do
      scaffold.new.invoke(:scaffold, nil, %w[user --crud])
      content = File.read('models/data/user.yml')
      expect(content).to include('default:')
      expect(content).to include('valid:')
      expect(content).to include('invalid:')
    end
  end

  # --- Feature: Destroy command ---

  describe 'destroy command' do
    it 'removes page and spec files' do
      scaffold.new.invoke(:scaffold, nil, %w[login])
      expect(Pathname.new('page_objects/pages/login.rb')).to be_file
      expect(Pathname.new('spec/login_page_spec.rb')).to be_file

      scaffold.new.invoke(:destroy, nil, %w[login])
      expect(Pathname.new('page_objects/pages/login.rb')).not_to be_file
      expect(Pathname.new('spec/login_page_spec.rb')).not_to be_file
    end

    it 'removes only specified components with --with' do
      scaffold.new.invoke(:scaffold, nil, %w[checkout --with page spec helper])
      expect(Pathname.new('page_objects/pages/checkout.rb')).to be_file
      expect(Pathname.new('spec/checkout_page_spec.rb')).to be_file
      expect(Pathname.new('helpers/checkout_helper.rb')).to be_file

      scaffold.new.invoke(:destroy, nil, %w[checkout --with page helper])
      expect(Pathname.new('page_objects/pages/checkout.rb')).not_to be_file
      expect(Pathname.new('helpers/checkout_helper.rb')).not_to be_file
      expect(Pathname.new('spec/checkout_page_spec.rb')).to be_file
    end

    it 'destroys multiple names at once' do
      scaffold.new.invoke(:scaffold, nil, %w[login dashboard])
      scaffold.new.invoke(:destroy, nil, %w[login dashboard])
      expect(Pathname.new('page_objects/pages/login.rb')).not_to be_file
      expect(Pathname.new('page_objects/pages/dashboard.rb')).not_to be_file
    end
  end

  # --- Feature: Template overrides ---

  describe 'template overrides' do
    before do
      FileUtils.mkdir_p('.ruby_raider/templates')
    end

    after do
      FileUtils.rm_rf('.ruby_raider')
    end

    it 'uses override template when present' do
      File.write('.ruby_raider/templates/page_object.tt', <<~ERB)
        # Custom page for <%= class_name %>
        class <%= page_class_name %> < Page
          # CUSTOM OVERRIDE
        end
      ERB

      Scaffolding.new(%w[widget]).generate_page
      content = File.read('page_objects/pages/widget.rb')
      expect(content).to include('CUSTOM OVERRIDE')
      expect(content).to include('class WidgetPage < Page')
    end

    it 'falls back to default template when no override exists' do
      Scaffolding.new(%w[gadget]).generate_page
      content = File.read('page_objects/pages/gadget.rb')
      expect(content).not_to include('CUSTOM OVERRIDE')
      expect(content).to include('class GadgetPage < Page')
    end
  end

  # --- Feature 3: Spec from page ---

  describe 'spec from page (--from)' do
    before do
      File.write('page_objects/pages/login.rb', <<~RUBY)
        class LoginPage < Page
          def login(username, password)
            username_field.send_keys username
          end

          def welcome_message
            driver.find_element(css: '.welcome').text
          end

          private

          def username_field
            driver.find_element(id: 'username')
          end
        end
      RUBY
    end

    it 'generates spec with method stubs' do
      scaffold.new.invoke(:spec, nil, %w[login --from page_objects/pages/login.rb])
      expect(Pathname.new('spec/login_spec.rb')).to be_file
    end

    it 'spec includes describe blocks for each public method' do
      scaffold.new.invoke(:spec, nil, %w[login --from page_objects/pages/login.rb])
      content = File.read('spec/login_spec.rb')
      expect(content).to include("describe '#login'")
      expect(content).to include("describe '#welcome_message'")
    end

    it 'spec does not include private methods' do
      scaffold.new.invoke(:spec, nil, %w[login --from page_objects/pages/login.rb])
      content = File.read('spec/login_spec.rb')
      expect(content).not_to include('username_field')
    end
  end
end
