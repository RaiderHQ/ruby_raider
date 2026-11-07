# frozen_string_literal: true

require_relative 'content_helper'

describe 'Test file content' do
  # --- RSpec specs ---

  shared_examples 'valid rspec spec' do |project_name|
    subject(:spec) { read_generated(project_name, 'spec/login_page_spec.rb') }

    it 'has frozen_string_literal' do
      expect(spec).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(spec).to have_valid_ruby_syntax
    end

    it 'uses describe block' do
      expect(spec).to match(/describe 'Login'/)
    end

    it 'requires spec_helper' do
      expect(spec).to include("require_relative '../helpers/spec_helper'")
    end

    it 'requires model_factory' do
      expect(spec).to include("require_relative '../models/model_factory'")
    end

    it 'requires login page' do
      expect(spec).to include("require_relative '../page_objects/pages/login'")
    end

    it 'has before block' do
      expect(spec).to match(/before do/)
    end

    it 'has context blocks' do
      expect(spec).to include("context 'with right credentials'")
      expect(spec).to include("context 'with wrong credentials'")
    end
  end

  shared_examples 'selenium rspec spec' do |project_name|
    subject(:spec) { read_generated(project_name, 'spec/login_page_spec.rb') }

    it 'instantiates Login with driver' do
      expect(spec).to include('Login.new(driver)')
    end

    it 'uses visit method' do
      expect(spec).to include('.visit')
      expect(spec).not_to include('.visit_page')
    end
  end

  shared_examples 'logged in example' do |project_name|
    it 'adds a :logged_in example that reuses the saved login and keeps the login example' do
      spec = read_generated(project_name, 'spec/login_page_spec.rb')
      expect(spec).to include("describe 'Account', :logged_in", 'opens the account page with the saved login',
                              "describe 'Login' do", 'can successfully log in')
    end
  end

  # --- RSpec contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid rspec spec', name
    include_examples 'selenium rspec spec', name
    include_examples 'logged in example', name
  end
end

describe 'Example tests' do
  it 'asserts the selenium rspec spec with have_text and no eventually' do
    spec = read_generated('rspec_selenium', 'spec/login_page_spec.rb')
    expect(spec.scan('expect { account_page.welcome_message }.to have_text("Welcome back #{user[\'name\']}")').size).to eq(2)
    expect(spec).to include("expect { login_page.welcome_message }.to have_text('Login or register')")
    expect(spec).not_to include('eventually')
  end

  %w[ios android cross_platform].each do |automation|
    it "asserts the #{automation} rspec spec with have_text and no eventually" do
      spec = read_generated("rspec_#{automation}", 'spec/pdp_page_spec.rb')
      expect(spec).to include("expect { pdp_page.add_to_cart_button }.to have_text('Add to Cart')")
      expect(spec).not_to include('eventually')
    end

    it "writes the #{automation} page objects in plain Appium" do
      home = read_generated("rspec_#{automation}", 'page_objects/pages/home.rb')
      pdp = read_generated("rspec_#{automation}", 'page_objects/pages/pdp.rb')
      expect(home).to include('first_product.click')
      expect(home).not_to match(/\btap\(/)
      expect(pdp).to include('def add_to_cart_button').and match(/\b(driver\.find_element|element)\(/)
      expect(pdp).not_to include('add_to_cart_text')
    end
  end
end
