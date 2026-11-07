# frozen_string_literal: true

require 'yaml'
require_relative 'content_helper'

describe 'Page object content' do
  # --- Login page ---

  shared_examples 'valid login page' do |project_name|
    subject(:login) { read_generated(project_name, 'page_objects/pages/login.rb') }

    it 'has frozen_string_literal' do
      expect(login).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(login).to have_valid_ruby_syntax
    end

    it 'defines Login class inheriting from Page' do
      expect(login).to match(/class Login < Page/)
    end

    it 'requires the abstract page' do
      expect(login).to include("require_relative '../abstract/page'")
    end

    it 'defines a login method' do
      expect(login).to match(/def login\(username, password\)/)
    end

    it 'defines a url method' do
      expect(login).to match(/def url/)
    end
  end

  shared_examples 'selenium login page' do |project_name|
    subject(:login) { read_generated(project_name, 'page_objects/pages/login.rb') }

    it 'returns Selenium elements from the element methods' do
      expect(login).to include("driver.find_element(id: 'loginFrm_loginname')", "driver.find_element(id: 'loginFrm_password')",
                               "driver.find_element(by_role('button', name: 'Login'))")
      expect(login).not_to include('browser.')
    end

    it 'logs in by acting on the elements' do
      expect(login).to include('username_field.send_keys(username)', 'password_field.send_keys(password)', 'login_button.click')
      expect(login).to include('alias log_as login')
    end

    it 'has private element methods' do
      expect(login).to include('private')
      expect(login).to match(/def username_field/)
      expect(login).to match(/def password_field/)
      expect(login).to match(/def login_button/)
    end

    it 'does not include Capybara DSL' do
      expect(login).not_to include('Capybara::DSL')
      expect(login).not_to include('fill_in')
    end
  end

  # --- Abstract page ---

  shared_examples 'valid abstract page' do |project_name|
    subject(:page) { read_generated(project_name, 'page_objects/abstract/page.rb') }

    it 'has valid Ruby syntax' do
      expect(page).to have_valid_ruby_syntax
    end

    it 'defines Page class' do
      expect(page).to match(/class Page/)
    end

    it 'defines to_s method' do
      expect(page).to match(/def to_s/)
    end

    describe 'full_url' do
      # The generated full_url and base_url, loaded without the helpers the abstract page requires.
      let(:page_class) do
        methods = page[/^  def full_url.*?^  end\n\n(?:  #.*\n)*  def base_url.*?^  end\n/m]
        expect(methods).not_to be_nil
        Class.new { def url(_page) = 'index.php?rt=account/login' }.tap { |klass| klass.class_eval(methods) }
      end

      def full_url_with(base_url, path = nil)
        allow(YAML).to receive(:load_file).with('config/config.yml').and_return('url' => base_url)
        klass = page_class
        klass.define_method(:url) { |_page| path } if path
        klass.new.full_url(nil)
      end

      it 'adds the missing slash between a base url with a path and the page path' do
        expect(full_url_with('https://example.org/login')).to eq('https://example.org/login/index.php?rt=account/login')
      end

      it 'keeps a single slash when the base url already ends with one' do
        expect(full_url_with('https://example.org/login/')).to eq('https://example.org/login/index.php?rt=account/login')
      end

      it 'does not double the slash when the page path starts with one' do
        expect(full_url_with('https://example.org', '/index.php')).to eq('https://example.org/index.php')
      end

      it 'returns the page path alone when the config has no url' do
        expect(full_url_with(nil, 'https://other.example/index.php')).to eq('https://other.example/index.php')
        expect(full_url_with(nil, '/index.php')).to eq('/index.php')
      end
    end
  end

  shared_examples 'selenium abstract page' do |project_name|
    subject(:page) { read_generated(project_name, 'page_objects/abstract/page.rb') }

    it 'has attr_reader :driver' do
      expect(page).to include('attr_reader :driver')
    end

    it 'has initialize accepting driver' do
      expect(page).to match(/def initialize\(driver\)/)
    end

    it 'has visit with driver.navigate' do
      expect(page).to include('driver.navigate.to')
    end

    it 'does not include Capybara DSL' do
      expect(page).not_to include('Capybara::DSL')
    end
  end

  # --- Contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid login page', name
    include_examples 'selenium login page', name
    include_examples 'valid abstract page', name
    include_examples 'selenium abstract page', name
  end
end

describe 'Page helper wiring' do
  FRAMEWORKS.each do |framework|
    it "includes NetworkHelper only in #{framework} selenium" do
      %w[selenium ios android cross_platform].each do |automation|
        page = read_generated("#{framework}_#{automation}", 'page_objects/abstract/page.rb')
        expect(page.include?('include NetworkHelper')).to eq(automation == 'selenium')
      end
    end

    it "includes ScreenshotHelper only in #{framework} selenium" do
      %w[selenium ios android cross_platform].each do |automation|
        page = read_generated("#{framework}_#{automation}", 'page_objects/abstract/page.rb')
        expect(page.include?('include ScreenshotHelper')).to eq(automation == 'selenium')
        expect(page.include?("require_relative '../../helpers/screenshot_helper'")).to eq(automation == 'selenium')
      end
    end
  end
end

describe 'Abstract page layout' do
  FRAMEWORKS.each do |framework|
    %w[selenium ios android cross_platform].each do |automation|
      [true, false].each do |examples|
        it "has no blank line before the class end in #{framework} #{automation}#{' (skeleton)' unless examples}" do
          page = read_generated(ensure_project(framework:, automation:, examples:), 'page_objects/abstract/page.rb')
          expect(page).not_to match(/\n\n\s*end\s*\z/)
        end
      end
    end
  end
end

describe 'Example pages' do
  FRAMEWORKS.each do |framework|
    it "defines welcome_message on the abstract page in #{framework} selenium" do
      page = read_generated("#{framework}_selenium", 'page_objects/abstract/page.rb')
      expect(page).to include("def welcome_message\n    driver.find_element(css: '.welcome-msg')")
      expect(page).not_to include('Header', 'components/header')
    end

    %w[ios android cross_platform].each do |automation|
      context "with #{framework} and #{automation}" do
        let(:home) { read_generated("#{framework}_#{automation}", 'page_objects/pages/home.rb') }
        let(:pdp) { read_generated("#{framework}_#{automation}", 'page_objects/pages/pdp.rb') }

        it 'taps the first product and reads the add to cart text through the wait helper' do
          expect(home).to include('tap(first_product)')
          expect(pdp).to include('text(add_to_cart_button)')
          expect(home + pdp).not_to include('driver.wait', 'driver.find_element')
        end

        it 'returns locator hashes from the element methods' do
          if automation == 'cross_platform'
            expect(home).to include("{ ios: { accessibility_id: 'product-item-1' },")
            expect(pdp).to include("{ ios: { accessibility_id: 'add-to-cart-button' },")
            expect(home + pdp).not_to include('element(ios:')
          else
            expect(home).to include("{ accessibility_id: 'product-item-1' }")
            expect(pdp).to include("{ accessibility_id: 'add-to-cart-button' }")
          end
        end

        it 'has valid Ruby syntax' do
          expect(home).to have_valid_ruby_syntax
          expect(pdp).to have_valid_ruby_syntax
        end
      end
    end
  end
end

describe 'Page runtime wiring' do
  AUTOMATION_TYPES.each do |automation|
    it "requires the runtime and includes Raider::Helpers in #{automation}" do
      page = read_generated("#{FrameworkIndex::RSPEC}_#{automation}", 'page_objects/abstract/page.rb')
      expect(page).to include("require 'ruby_raider/runtime'", 'include Raider::Helpers')
    end
  end
end
