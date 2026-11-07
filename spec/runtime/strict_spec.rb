# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider strict find_element' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:driver) { Raider::Spec.driver(bridge) }

  before { allow(Raider::Describe).to receive(:element) { |element| "<el #{element.ref.last}>" } }

  after { Raider.reset }

  it 'raises AmbiguousMatch listing both matches' do
    bridge.enqueue(%w[a b])
    expect { driver.find_element(label: 'Email') }.to raise_error(Raider::AmbiguousMatch) { |error|
      expect(error.message).to include('label: "Email"')
      expect(error.message).to include('matched 2 elements', '<el a>', '<el b>')
    }
  end

  it 'returns the single match through one find_elements_by call' do
    bridge.enqueue(['a'])
    expect(driver.find_element(label: 'Email')).to be_a(Selenium::WebDriver::Element)
    expect(bridge.calls.map(&:first)).to eq([:find_elements_by])
  end

  it 'raises NoSuchElementError when nothing matches' do
    bridge.enqueue([])
    expect { driver.find_element(label: 'Email') }
      .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /no such element: \{ label: "Email" \}/)
  end

  it 'goes back to find_element_by when strict is off' do
    Raider.strict = false
    bridge.enqueue(['a'])
    driver.find_element(label: 'Email')
    expect(bridge.calls.map(&:first)).to eq([:find_element_by])
  end

  it 'passes the element ref through for an element scope' do
    bridge.enqueue(['a'])
    Selenium::WebDriver::Element.new(bridge, 'root').find_element(label: 'Email')
    expect(bridge.calls.last).to end_with([:element, 'root'])
    expect(bridge.calls.last.first).to eq(:find_elements_by)
  end

  it 'makes driver.first strict' do
    bridge.enqueue(%w[a b])
    expect { driver.first(label: 'Email') }.to raise_error(Raider::AmbiguousMatch)
    expect(bridge.calls.map(&:first)).to eq([:find_elements_by])
  end

  it 'makes element.first strict' do
    bridge.enqueue(%w[a b])
    expect { Selenium::WebDriver::Element.new(bridge, 'root').first(label: 'Email') }.to raise_error(Raider::AmbiguousMatch)
    expect(bridge.calls.map(&:first)).to eq([:find_elements_by])
  end

  it 'sends driver.first back to find_element_by when strict is off' do
    Raider.strict = false
    bridge.enqueue(['a'])
    driver.first(label: 'Email')
    expect(bridge.calls.map(&:first)).to eq([:find_element_by])
  end

  it 'leaves find_elements alone' do
    bridge.enqueue(%w[a b])
    expect(driver.find_elements(label: 'Email').size).to eq(2)
  end

  context 'with an Appium bridge' do
    let(:context_name) { 'NATIVE_APP' }
    let(:bridge) do
      name = context_name
      klass = stub_const('Appium::Core::Base::Bridge', Class.new(Raider::Spec::FakeBridge) do
        class << self; attr_accessor :locator_converter; end
        define_method(:current_context) { name }
      end)
      klass.locator_converter = Selenium::WebDriver::Remote::Bridge::LocatorConverter.new
      klass.new
    end

    it 'does not apply strictness on NATIVE_APP' do
      bridge.enqueue(%w[a b])
      driver.find_element(id: 'x')
      expect(bridge.calls.map(&:first)).to eq([:find_element_by])
    end

    context 'in a webview' do
      let(:context_name) { 'WEBVIEW_1' }

      it 'applies strictness' do
        bridge.enqueue(%w[a b])
        expect { driver.find_element(id: 'x') }.to raise_error(Raider::AmbiguousMatch)
      end

      it 'asks for the context once on a strict role find' do
        bridge.script_results << ['a']
        allow(bridge).to receive(:current_context).and_call_original
        driver.find_element(role: 'button')
        expect(bridge).to have_received(:current_context).once
      end

      it 'asks for the context once on a strict css find' do
        bridge.enqueue(['a'])
        allow(bridge).to receive(:current_context).and_call_original
        driver.find_element(css: 'x')
        expect(bridge).to have_received(:current_context).once
      end
    end
  end

  describe Raider::Locator do
    it 'describes a role with options as by_role' do
      expect(described_class.describe([{ role: ['button', { name: 'Save' }] }])).to eq("by_role('button', name: \"Save\")")
    end

    it 'shows the heading level' do
      expect(described_class.describe([Raider.by_role('heading', level: 2)])).to eq("by_role('heading', level: 2)")
    end

    it 'describes a role without options' do
      expect(described_class.describe([{ role: ['button', {}] }])).to eq("by_role('button')")
    end

    it 'describes a plain key' do
      expect(described_class.describe([{ label: 'Email' }])).to eq('{ label: "Email" }')
    end

    it 'shows exact when set' do
      expect(described_class.describe([{ label: ['Email', { exact: true }] }])).to eq('{ label: "Email", exact: true }')
    end

    it 'describes the two-argument form' do
      expect(described_class.describe(['css selector', '.a'])).to eq('{ "css selector": ".a" }')
    end

    it 'never raises on odd shapes' do
      [[], [nil], [{ role: [] }], [{ role: 5 }], [1, 2, 3]].each do |args|
        expect(described_class.describe(args)).to be_a(String)
      end
    end
  end
end
