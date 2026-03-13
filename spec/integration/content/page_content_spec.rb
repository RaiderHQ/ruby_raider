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

    it 'uses find_element for elements' do
      expect(login).to include('driver.find_element')
    end

    it 'uses send_keys for input' do
      expect(login).to include('send_keys')
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

  shared_examples 'capybara login page' do |project_name|
    subject(:login) { read_generated(project_name, 'page_objects/pages/login.rb') }

    it 'uses fill_in for input' do
      expect(login).to include('fill_in')
    end

    it 'uses click_button' do
      expect(login).to include('click_button')
    end

    it 'has no private element methods' do
      expect(login).not_to include('private')
      expect(login).not_to match(/def username_field/)
    end

    it 'does not include Selenium methods' do
      expect(login).not_to include('find_element')
      expect(login).not_to include('send_keys')
    end

    it 'does not include Watir methods' do
      expect(login).not_to include('browser.text_field')
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

  shared_examples 'capybara abstract page' do |project_name|
    subject(:page) { read_generated(project_name, 'page_objects/abstract/page.rb') }

    it 'includes Capybara::DSL' do
      expect(page).to include('include Capybara::DSL')
    end

    it 'uses visit_page method' do
      expect(page).to match(/def visit_page/)
    end

    it 'uses Capybara.visit' do
      expect(page).to include('Capybara.visit')
    end

    it 'does not have attr_reader :driver' do
      expect(page).not_to include('attr_reader :driver')
    end

    it 'does not have initialize with driver' do
      expect(page).not_to match(/def initialize\(driver\)/)
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

  context 'with rspec and capybara' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CAPYBARA}"
    include_examples 'valid login page', name
    include_examples 'capybara login page', name
    include_examples 'valid abstract page', name
    include_examples 'capybara abstract page', name
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

  context 'with cucumber and capybara' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CAPYBARA}"
    include_examples 'valid login page', name
    include_examples 'capybara login page', name
    include_examples 'valid abstract page', name
    include_examples 'capybara abstract page', name
  end

  context 'with minitest and selenium' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid login page', name
    include_examples 'selenium login page', name
    include_examples 'valid abstract page', name
    include_examples 'selenium abstract page', name
  end

  context 'with minitest and watir' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}"
    include_examples 'valid login page', name
    include_examples 'watir login page', name
    include_examples 'valid abstract page', name
    include_examples 'watir abstract page', name
  end

  context 'with minitest and capybara' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}"
    include_examples 'valid login page', name
    include_examples 'capybara login page', name
    include_examples 'valid abstract page', name
    include_examples 'capybara abstract page', name
  end
end
