# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider role finder' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:driver) { Raider::Spec.driver(bridge) }
  let(:locator) { Raider.by_role('button', name: 'Save') }
  let(:options) { { 'name' => 'Save', 'exact' => false, 'includeHidden' => false, 'level' => nil } }

  before { allow(Raider::Describe).to receive(:element) { |element| "<el #{element.ref.last}>" } }

  after { Raider.reset }

  # These examples are about the role engine, so each find makes one attempt.
  around { |example| Raider::Wait.immediately { example.run } }

  def element(id)
    Selenium::WebDriver::Element.new(bridge, id)
  end

  it 'queries the engine with a nil scope from the driver' do
    bridge.script_results << [element('a')]
    driver.find_elements(locator)
    expect(bridge.script_calls.first.drop(1)).to eq([nil, 'button', options])
  end

  it 'scopes the query to the element' do
    scope = element('s')
    bridge.script_results << []
    scope.find_elements(Raider.by_role('listitem'))
    expect(bridge.script_calls.first.drop(1)).to eq([scope, 'listitem', { 'name' => nil, 'exact' => false,
                                                                          'includeHidden' => false, 'level' => nil }])
  end

  it 'scopes the query to a shadow root instead of the document' do
    shadow = Selenium::WebDriver::ShadowRoot.new(bridge, 'sr')
    bridge.script_results << []
    shadow.find_elements(Raider.by_role('button'))
    expect(bridge.script_calls.first[1]).to equal(shadow)
  end

  it 'carries a heading level and rejects bad ones before any script runs' do
    bridge.script_results << []
    driver.find_elements(Raider.by_role('heading', level: 2))
    expect(bridge.script_calls.first.last).to include('level' => 2)
    [{ role: ['button', { level: 2 }] }, { role: ['heading', { level: 7 }] }, { role: ['heading', { level: '2' }] }].each do |bad|
      expect { driver.find_elements(bad) }.to raise_error(ArgumentError, /level/)
    end
    expect(bridge.script_calls.size).to eq(1)
  end

  it 'accepts the two-argument form and string option keys' do
    bridge.script_results << []
    driver.find_elements(:role, ['button', { 'name' => 'Save' }])
    expect(bridge.script_calls.first.drop(1)).to eq([nil, 'button', options])
  end

  it 'accepts a bare role string' do
    bridge.script_results << []
    driver.find_elements(role: 'button')
    expect(bridge.script_calls.first[2]).to eq('button')
  end

  it 'accepts a string role key in both forms' do
    bridge.script_results.push([], [])
    driver.find_elements('role' => ['button', { name: 'Save' }])
    driver.find_elements('role', ['button', { name: 'Save' }])
    expect(bridge.script_calls.map { |call| call.drop(1) }).to eq([[nil, 'button', options]] * 2)
  end

  it 'finds a single element through a string role key' do
    bridge.script_results << [element('a')]
    expect(driver.find_element('role' => 'button').ref.last).to eq('a')
  end

  {
    'a nil value' => { role: nil },
    'an unknown role' => { role: 'buton' },
    'a Hash value' => { role: { a: 1 } },
    'a blank role' => { role: ['', { name: 'x' }] },
    'non-Hash options' => { role: %w[button Save] },
    'a Regexp name' => { role: ['button', { name: /Save/ }] }
  }.each do |label, locator|
    it "raises ArgumentError for #{label} before any script runs" do
      expect { driver.find_elements(locator) }.to raise_error(ArgumentError, /role|unknown role/)
      expect { driver.find_element(locator) }.to raise_error(ArgumentError)
      expect(bridge.script_calls).to be_empty
    end
  end

  it 'raises AmbiguousMatch from find_element on two matches' do
    bridge.script_results << [element('a'), element('b')]
    expect { driver.find_element(locator) }.to raise_error(Raider::AmbiguousMatch) { |error|
      expect(error.message).to start_with('`by_role(\'button\', name: "Save")` matched 2 elements')
    }
  end

  it 'returns the single match' do
    bridge.script_results << [element('a')]
    expect(driver.find_element(locator).ref.last).to eq('a')
  end

  it 'returns the first match when strict is off' do
    Raider.strict = false
    bridge.script_results << [element('a'), element('b')]
    expect(driver.find_element(locator).ref.last).to eq('a')
  end

  it 'raises NoSuchElementError with no matches' do
    bridge.script_results << []
    expect { driver.find_element(locator) }
      .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /no such element: by_role\('button', name: "Save"\)/)
  end

  it 'raises NoSuchElementError with no matches when strict is off' do
    Raider.strict = false
    bridge.script_results << []
    expect { driver.find_element(locator) }
      .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /no such element: by_role/)
  end

  it 'propagates a JavascriptError that is not about the engine' do
    bridge.script_results << Selenium::WebDriver::Error::JavascriptError.new('boom')
    expect { driver.find_elements(locator) }.to raise_error(Selenium::WebDriver::Error::JavascriptError, 'boom')
  end

  it 'leaves other locators for Selenium' do
    bridge.enqueue(%w[a b])
    expect(driver.find_elements(css: 'x').size).to eq(2)
    expect(bridge.calls.first.first).to eq(:find_elements_by)
    expect(bridge.script_calls).to be_empty
  end

  context 'with an Appium NATIVE_APP bridge' do
    let(:bridge) do
      klass = stub_const('Appium::Core::Base::Bridge', Class.new(Raider::Spec::FakeBridge) do
        class << self; attr_accessor :locator_converter; end
        define_method(:current_context) { 'NATIVE_APP' }
      end)
      klass.locator_converter = Selenium::WebDriver::Remote::Bridge::LocatorConverter.new
      klass.new
    end

    it 'raises NotSupported' do
      expect { driver.find_elements(locator) }
        .to raise_error(Raider::NotSupported, 'by_role needs a web context; use accessibility_id on native screens')
    end

    it 'raises NotSupported from find_element too' do
      expect { driver.find_element(locator) }.to raise_error(Raider::NotSupported)
    end
  end
end
