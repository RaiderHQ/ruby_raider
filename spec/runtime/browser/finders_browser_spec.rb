# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../support/browser'

RSpec.describe 'Raider finders in a real browser', :browser do
  let(:driver) { Raider::Spec::Browser.driver }

  before(:all) { Raider::Spec::Browser.open('locators.html') } # rubocop:disable RSpec/BeforeAfterAll

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  def id_of(element)
    element.attribute('id')
  end

  describe 'label:' do
    it 'finds a field through label for' do
      expect(id_of(driver.find_element(label: 'Password'))).to eq('password')
    end

    it 'finds a field inside a wrapping label' do
      expect(id_of(driver.find_element(label: 'Username'))).to eq('username')
    end

    it 'finds a field by aria-label' do
      expect(id_of(driver.find_element(label: 'Search site'))).to eq('search')
    end

    it 'finds a field by aria-labelledby' do
      expect(id_of(driver.find_element(label: 'Phone number'))).to eq('phone')
    end

    it 'matches a substring and skips the longer label under exact: true' do
      expect(id_of(driver.find_element(label: 'Email address'))).to eq('email-address')
      expect(id_of(driver.find_element(label: ['Email address', { exact: true }]))).to eq('email-address')
    end

    it 'skips the longer label when the exact label is scoped' do
      scope = driver.find_element(id: 'scope')
      expect(id_of(scope.find_element(label: ['Email', { exact: true }]))).to eq('scoped-email')
    end

    it 'treats a substring as ambiguous and exact as unique' do
      expect { driver.find_element(label: 'Email') }.to raise_error(Raider::AmbiguousMatch)
      expect(driver.find_elements(label: 'Email').size).to eq(3)
      expect(driver.find_elements(label: ['Email', { exact: true }]).size).to eq(2)
    end

    it 'scopes to the section' do
      scope = driver.find_element(id: 'scope')
      expect(id_of(scope.find_element(label: 'Email'))).to eq('scoped-email')
    end

    it 'raises NoSuchElementError when nothing matches' do
      expect { driver.find_element(label: 'Nope') }.to raise_error(Selenium::WebDriver::Error::NoSuchElementError)
    end
  end

  describe 'placeholder:' do
    it 'matches a substring' do
      expect(driver.find_elements(placeholder: 'Enter').size).to eq(2)
    end

    it 'matches exactly' do
      expect(id_of(driver.find_element(placeholder: ['Enter code', { exact: true }]))).to eq('code')
    end
  end

  it 'finds an image by alt' do
    expect(id_of(driver.find_element(alt: 'Company logo'))).to eq('logo')
  end

  it 'finds a link by title' do
    expect(id_of(driver.find_element(title: 'Read the docs'))).to eq('docs-link')
  end

  describe 'text:' do
    it 'returns the innermost element, not its ancestor' do
      expect(id_of(driver.find_element(text: 'Sign in'))).to eq('sign-in')
    end

    it 'raises AmbiguousMatch naming three buttons' do
      expect { driver.find_element(text: 'Save') }.to raise_error(Raider::AmbiguousMatch) { |error|
        expect(error.message).to include('matched 3 elements', '(+0 more)')
        expect(error.message).to include('<button id="save-a" class="primary">Save</button>',
                                         '<button id="save-b" class="secondary">Save</button>')
      }
    end

    it 'find_elements is never strict' do
      expect(driver.find_elements(text: 'Save').size).to eq(3)
    end
  end

  describe 'test_id:' do
    it 'matches the data-testid value exactly' do
      expect(driver.find_elements(test_id: 'item').size).to eq(0)
      expect(id_of(driver.find_element(test_id: 'item-1'))).to eq('item-one')
      expect(id_of(driver.find_element(test_id: 'item-2'))).to eq('item-two')
    end
  end

  describe 'with a BiDi session' do
    let(:bidi_driver) { Raider::Spec::Browser.bidi_driver }

    before(:all) { Raider::Spec::Browser.bidi_driver.navigate.to(Raider::Spec::Browser.fixture_url('locators.html')) } # rubocop:disable RSpec/BeforeAfterAll

    after(:all) { Raider::Spec::Browser.quit_bidi } # rubocop:disable RSpec/BeforeAfterAll

    it 'finds a field by label through the BiDi bridge' do
      expect(id_of(bidi_driver.find_element(label: 'Password'))).to eq('password')
    end
  end
end
