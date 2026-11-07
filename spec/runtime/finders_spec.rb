# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider finders' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:driver) { Raider::Spec.driver(bridge) }
  let(:search_context) { Selenium::WebDriver::SearchContext }

  before { bridge.enqueue(['a']) }

  it 'registers every Raider key with Selenium' do
    expect(search_context.finders).to include(Raider::FINDERS)
  end

  it 'converts label to xpath' do
    driver.find_element(label: 'Email')
    expect(bridge.calls.last).to eq([:find_elements_by, 'xpath', Raider::Selectors.label('Email', exact: false), [:driver, nil]])
  end

  it 'converts text to xpath' do
    driver.find_element(text: ['Go', { exact: true }])
    expect(bridge.calls.last[1..2]).to eq(['xpath', Raider::Selectors.text('Go', exact: true)])
  end

  it 'converts placeholder with exact to css' do
    driver.find_element(placeholder: ['Name', { exact: true }])
    expect(bridge.calls.last[1..2]).to eq(['css selector', '[placeholder="Name"]'])
  end

  it 'converts alt and title to css' do
    driver.find_element(alt: 'Logo')
    driver.find_elements(title: 'Help')
    expect(bridge.calls.map { |call| call[2] }).to eq(['[alt*="Logo"]', '[title*="Help"]'])
  end

  it 'converts test_id to an exact css match' do
    driver.find_element(test_id: 'x')
    expect(bridge.calls.last[1..2]).to eq(['css selector', Raider::Selectors.test_id('x')])
  end

  it 'leaves other keys to the inner converter' do
    driver.find_element(id: 'x')
    expect(bridge.calls.last[1..2]).to eq(['css selector', '#x'])
  end

  it 'passes the element ref for an element scope' do
    element = Selenium::WebDriver::Element.new(bridge, 'root')
    element.find_element(label: 'Email')
    expect(bridge.calls.last.last).to eq([:element, 'root'])
    expect(bridge.calls.last[2].split(' | ')).to all(start_with('.//'))
  end

  it 'guards the converter role branch with an internal error' do
    expect { Raider::LocatorConverter.new(nil).convert(Raider::LocatorConverter::ROLE, 'button') }
      .to raise_error(Raider::NotSupported, /did not intercept/)
  end

  it 'raises ArgumentError naming the key for a malformed value' do
    expect { driver.find_element(label: [1, {}]) }.to raise_error(ArgumentError, /label/)
    expect { driver.find_element(label: %w[a b]) }.to raise_error(ArgumentError, /label/)
  end

  it 'rejects nil and blank values' do
    [{ label: nil }, { text: '' }, { placeholder: ['  ', {}] }].each do |locator|
      expect { driver.find_element(locator) }.to raise_error(ArgumentError, /#{locator.keys.first}: needs a non-empty value/)
    end
  end

  describe '.install_converter' do
    it 'is idempotent' do
      bridge_class = Selenium::WebDriver::Remote::Bridge
      before_converter = bridge_class.locator_converter
      Raider::Finders.install_converter(bridge_class)
      expect(bridge_class.locator_converter).to equal(before_converter)
    end

    it 'wraps a plain converter exactly once' do
      klass = Class.new { class << self; attr_accessor :locator_converter; end }
      klass.locator_converter = Selenium::WebDriver::Remote::Bridge::LocatorConverter.new
      2.times { Raider::Finders.install_converter(klass) }
      expect(klass.locator_converter.inner).not_to be_a(Raider::LocatorConverter)
    end
  end

  describe 'with Appium finders assigned after Raider' do
    around do |example|
      previous = search_context.extra_finders
      example.run
    ensure
      search_context.extra_finders = previous
    end

    before do
      stub_const('Appium::Core::Base::SearchContext::APPIUM_EXTRA_FINDERS', { accessibility_id: 'accessibility id' })
      search_context.extra_finders = Appium::Core::Base::SearchContext::APPIUM_EXTRA_FINDERS
    end

    it 'keeps both tables after register' do
      Raider::Finders.register
      expect(search_context.finders).to include(:accessibility_id, :label)
    end

    it 'restores the keys through ensure_registered' do
      expect(search_context.finders).not_to include(:label)
      Raider::Finders.ensure_registered
      expect(search_context.finders).to include(:accessibility_id, :label)
    end
  end

  describe '.ensure_registered with a late Appium bridge' do
    it 'wraps the converter Appium assigned' do
      appium = stub_const('Appium::Core::Base::Bridge', Class.new(Selenium::WebDriver::Remote::Bridge))
      inner = Selenium::WebDriver::Remote::Bridge::LocatorConverter.new
      appium.locator_converter = inner
      Raider::Finders.ensure_registered
      expect(appium.locator_converter).to be_a(Raider::LocatorConverter)
      expect(appium.locator_converter.inner).to equal(inner)
    end
  end

  describe 'BiDi bridges' do
    it 'gives the Selenium BiDi bridge class the Raider converter' do
      expect(Selenium::WebDriver::Remote::BiDiBridge.locator_converter).to be_a(Raider::LocatorConverter)
    end

    it 'gives a BiDi bridge instance the Raider converter' do
      bidi = Raider::Spec.real_bridge(Selenium::WebDriver::Remote::BiDiBridge)
      expect(bidi.instance_variable_get(:@locator_converter)).to be_a(Raider::LocatorConverter)
    end

    it 'wraps a late Appium BiDi bridge in ensure_registered' do
      appium = stub_const('Appium::Core::Base::BiDiBridge', Class.new(Selenium::WebDriver::Remote::BiDiBridge))
      inner = Selenium::WebDriver::Remote::Bridge::LocatorConverter.new
      appium.locator_converter = inner
      Raider::Finders.ensure_registered
      expect(appium.locator_converter).to be_a(Raider::LocatorConverter)
      expect(appium.locator_converter.inner).to equal(inner)
    end
  end

  describe '.guard' do
    it 'raises when a bridge already exists' do
      existing = Selenium::WebDriver::Remote::Bridge.allocate
      expect { Raider::Finders.guard }.to raise_error(Raider::Error, /before creating the driver/)
      expect(existing).to be_a(Selenium::WebDriver::Remote::Bridge)
    end
  end

  describe '.check_api' do
    it 'raises when the bridge cannot take a converter' do
      allow(Selenium::WebDriver::Remote::Bridge).to receive(:respond_to?).and_call_original
      allow(Selenium::WebDriver::Remote::Bridge).to receive(:respond_to?).with(:locator_converter=).and_return(false)
      expect { Raider::Finders.check_api }.to raise_error(Raider::Error, /locator_converter=/)
    end

    it 'raises when SearchContext cannot take extra finders' do
      allow(search_context).to receive(:respond_to?).and_call_original
      allow(search_context).to receive(:respond_to?).with(:extra_finders=).and_return(false)
      expect { Raider::Finders.check_api }.to raise_error(Raider::Error, /extra_finders=/)
    end
  end
end
