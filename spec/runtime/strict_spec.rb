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
    Raider.timeout = 0
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

  it 'returns find_elements results that already match without waiting' do
    bridge.enqueue(%w[a b])
    expect(driver.find_elements(label: 'Email').size).to eq(2)
  end

  describe 'waiting for a match' do
    def find_calls(command = :find_elements_by)
      bridge.calls.count { |call| call.first == command }
    end

    it 'returns the element once it shows up, after three calls' do
      bridge.enqueue([])
      bridge.enqueue([])
      bridge.enqueue(['a'])
      expect(driver.find_element(id: 'x')).to be_a(Selenium::WebDriver::Element)
      expect(find_calls).to eq(3)
    end

    it 'raises NoSuchElementError naming the wait when nothing ever matches' do
      Raider.timeout = 0.3
      expect { driver.find_element(id: 'x') }
        .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /no such element: \{ id: "x" \} \(waited 0\.[34]\d?s\)/)
    end

    it 'waits the same way when strict is off' do
      Raider.strict = false
      Raider.timeout = 0.3
      expect { driver.find_element(id: 'x') }
        .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /\(waited 0\.[34]\d?s\)/)
      expect(find_calls(:find_element_by)).to be >= 3
    end

    it 'raises AmbiguousMatch on the first call' do
      bridge.enqueue(%w[a b])
      expect { driver.find_element(id: 'x') }.to raise_error(Raider::AmbiguousMatch)
      expect(find_calls).to eq(1)
    end

    it 'returns the elements of find_elements once they show up, after three calls' do
      bridge.enqueue([])
      bridge.enqueue([])
      bridge.enqueue(%w[a b])
      expect(driver.find_elements(css: '.row').size).to eq(2)
      expect(find_calls).to eq(3)
    end

    it 'returns [] from find_elements after about the timeout' do
      Raider.timeout = 0.3
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(driver.find_elements(css: '.row')).to eq([])
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be_between(0.25, 0.6)
    end

    it 'makes one call per find inside Wait.immediately' do
      Raider.timeout = 5
      Raider::Wait.immediately do
        expect(driver.find_elements(css: '.row')).to eq([])
        expect { driver.find_element(id: 'x') }.to raise_error(Selenium::WebDriver::Error::NoSuchElementError)
      end
      expect(bridge.calls.map(&:first)).to eq(%i[find_elements_by find_elements_by])
    end

    it 'makes one call per find on the native path inside Wait.immediately' do
      Raider.strict = false
      Raider::Wait.immediately do
        expect { driver.find_element(id: 'x') }.to raise_error(Selenium::WebDriver::Error::NoSuchElementError)
      end
      expect(bridge.calls.map(&:first)).to eq([:find_element_by])
    end
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

    it 'waits for a match on NATIVE_APP too' do
      Raider.timeout = 0.3
      bridge.enqueue([])
      bridge.enqueue(['a'])
      expect(driver.find_element(id: 'x')).to be_a(Selenium::WebDriver::Element)
      expect { driver.find_element(id: 'gone') }
        .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /\(waited 0\.[34]\d?s\)/)
      expect(driver.find_elements(id: 'gone')).to eq([])
    end

    it 'reports the elapsed wait, not the timeout, inside a shorter enclosing wait' do
      Raider.timeout = 5
      expect { Raider::Wait.until(timeout: 0.2) { driver.find_element(id: 'x') } }
        .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /\(waited 0\.[23]\d?s\)/)
    end

    it 'raises NotSupported at once for a role find on NATIVE_APP' do
      Raider.timeout = 5
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { driver.find_element(role: 'button') }.to raise_error(Raider::NotSupported)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
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

      it 'asks for the context once on a strict role find that waits several polls' do
        bridge.script_results.push([], [], ['a'])
        allow(bridge).to receive(:current_context).and_call_original
        driver.find_element(role: 'button')
        expect(bridge).to have_received(:current_context).once
      end

      it 'asks for the context once on a non-strict role find that waits several polls' do
        Raider.strict = false
        bridge.script_results.push([], [], ['a'])
        allow(bridge).to receive(:current_context).and_call_original
        driver.find_element(role: 'button')
        expect(bridge).to have_received(:current_context).once
      end

      it 'asks for the context once on a role find_elements that waits several polls' do
        bridge.script_results.push([], [], ['a'])
        allow(bridge).to receive(:current_context).and_call_original
        expect(driver.find_elements(role: 'button').size).to eq(1)
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
