# frozen_string_literal: true

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

    it 'returns locator hashes from the element methods' do
      expect(login).to include("{ id: 'loginFrm_loginname' }", "{ id: 'loginFrm_password' }",
                               %q({ xpath: "//button[@title='Login']" }))
      expect(login).not_to include('driver.find_element')
    end

    it 'logs in through the wait helper' do
      expect(login).to include('send_keys(username_field, username)', 'send_keys(password_field, password)',
                               'click(login_button)')
      expect(login).not_to include('.send_keys', '.click')
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

    it 'does not include Watir methods' do
      expect(login).not_to include('browser.text_field')
    end
  end

  shared_examples 'watir login page' do |project_name|
    subject(:login) { read_generated(project_name, 'page_objects/pages/login.rb') }

    it 'uses browser methods for elements' do
      expect(login).to include('browser.text_field')
      expect(login).to include('browser.button')
    end

    it 'uses set for input' do
      expect(login).to include('.set ')
    end

    it 'does not include Selenium methods' do
      expect(login).not_to include('find_element')
      expect(login).not_to include('send_keys')
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

  shared_examples 'watir abstract page' do |project_name|
    subject(:page) { read_generated(project_name, 'page_objects/abstract/page.rb') }

    it 'has attr_reader :browser' do
      expect(page).to include('attr_reader :browser')
    end

    it 'has initialize accepting browser' do
      expect(page).to match(/def initialize\(browser\)/)
    end

    it 'has visit with browser.goto' do
      expect(page).to include('browser.goto')
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

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid login page', name
    include_examples 'watir login page', name
    include_examples 'valid abstract page', name
    include_examples 'watir abstract page', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid login page', name
    include_examples 'selenium login page', name
    include_examples 'valid abstract page', name
    include_examples 'selenium abstract page', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'valid login page', name
    include_examples 'watir login page', name
    include_examples 'valid abstract page', name
    include_examples 'watir abstract page', name
  end
end

describe 'Page WaitHelper wiring' do
  %w[rspec cucumber].each do |framework|
    %w[selenium ios android cross_platform].each do |automation|
      it "includes WaitHelper in #{framework} #{automation}" do
        page = read_generated("#{framework}_#{automation}", 'page_objects/abstract/page.rb')
        expect(page).to include("require_relative '../../helpers/wait_helper'", 'include WaitHelper')
      end
    end

    it "does not include WaitHelper in #{framework} watir" do
      expect(read_generated("#{framework}_watir", 'page_objects/abstract/page.rb')).not_to include('WaitHelper')
    end
  end
end

describe 'Example pages on the wait helper' do
  %w[rspec cucumber].each do |framework|
    it "finds the header through the wait helper in #{framework} selenium" do
      page = read_generated("#{framework}_selenium", 'page_objects/abstract/page.rb')
      expect(page).to include("Header.new(find_element(css: '.welcome-msg'))")
      expect(page).not_to include('driver.find_element')
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
