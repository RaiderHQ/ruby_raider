# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider::Actionability' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:element) { Selenium::WebDriver::Element.new(bridge, 'e1') }
  let(:overlay) { { 'check' => 'events', 'covering' => { 'element' => '<div class="overlay">', 'x' => 412, 'y' => 300 } } }

  before do
    Raider.reset
    Raider::Actionability.reset_notice
    allow($stderr).to receive(:puts)
  end

  after { Raider.reset }

  it 'makes no script call when actionability is off' do
    Raider.actionability = false
    Raider::Actionability.ensure(element, :click, force: false)
    expect(bridge.script_calls).to be_empty
  end

  it 'makes no script call but one tag_name command when forced' do
    bridge.answer(:element_tag_name, 'div')
    Raider::Actionability.ensure(element, :click, force: true)
    expect([bridge.script_calls, bridge.calls]).to eq([[], [[:element_tag_name, 'e1']]])
  end

  it 'polls until the check returns nil' do
    bridge.script_results.push({ 'check' => 'visible' }, { 'check' => 'visible' }, nil)
    Raider::Actionability.ensure(element, :click, force: false)
    expect(bridge.script_calls.size).to eq(3)
  end

  it 'pauses briefly and re-checks at once after a first stable poll' do
    first = { 'check' => 'stable', 'first' => true }
    bridge.script_results.push(first, nil)
    allow(Raider::Actionability).to receive(:sleep)
    Raider::Actionability.ensure(element, :click, force: false)
    expect(Raider::Actionability).to have_received(:sleep).with(0.02).once
    expect(bridge.script_calls.size).to eq(2)
  end

  it 'passes the script and the action checks to the browser' do
    bridge.script_results.push(nil)
    Raider::Actionability.ensure(element, :submit, force: false)
    expect(bridge.script_calls.first).to eq([Raider::Actionability::SCRIPT, element, %w[visible enabled inert]])
  end

  it 'raises NotActionable naming the covering element' do
    Raider.timeout = 0.3
    bridge.script_results.concat([overlay] * 20)
    expect { Raider::Actionability.ensure(element, :click, force: false) }
      .to raise_error(Raider::NotActionable, /receive events; `<div class="overlay">` covers it at \(412, 300\)/)
  end

  it 'returns zero when actionability is off or forced' do
    Raider.actionability = false
    off = Raider::Actionability.ensure(element, :click, force: false)
    Raider.actionability = true
    bridge.answer(:element_tag_name, 'div')
    expect([off, Raider::Actionability.ensure(element, :click, force: true)]).to eq([0, 0])
  end

  it 'returns the number of not-ready polls on the web' do
    bridge.script_results.push({ 'check' => 'visible' }, { 'check' => 'enabled' }, nil)
    expect(Raider::Actionability.ensure(element, :click, force: false)).to eq(2)
  end

  it 'does not count the first stable poll as not ready' do
    bridge.script_results.push({ 'check' => 'stable', 'first' => true }, nil)
    allow(Raider::Actionability).to receive(:sleep)
    expect(Raider::Actionability.ensure(element, :click, force: false)).to eq(0)
  end

  describe 'on an Appium native context' do
    let(:context) { 'NATIVE_APP' }
    let(:appium) do
      name = context
      Class.new(Raider::Spec::FakeBridge) { define_method(:current_context) { name } }.new
    end

    def native = @native ||= Selenium::WebDriver::Element.new(appium, 'e1')

    def ensure_native(action, **opts)
      Raider::Actionability.ensure(native, action, force: false, **opts)
    end

    it 'polls until displayed and enabled, then returns the not-ready count without a script call' do
      appium.answer(:element_displayed?, false, false, true).answer(:element_enabled?, false, true)
      expect(ensure_native(:click)).to eq(3)
      expect(appium.script_calls).to be_empty
    end

    it 'returns zero when ready at once' do
      appium.answer(:element_displayed?, true).answer(:element_enabled?, true)
      expect(ensure_native(:click)).to eq(0)
    end

    %i[click send_keys clear].each do |action|
      it "raises NotActionable to be visible for a hidden element on #{action}" do
        Raider.timeout = 0.3
        appium.answer(:element_displayed?, false).answer(:element_enabled?, true)
        expect { ensure_native(action) }.to raise_error(Raider::NotActionable, /waited 0\.3\d?s for .* to be visible/)
      end

      it "raises NotActionable to be enabled for a disabled element on #{action}" do
        Raider.timeout = 0.3
        appium.answer(:element_displayed?, true).answer(:element_enabled?, false)
        expect { ensure_native(action) }.to raise_error(Raider::NotActionable, /waited 0\.3\d?s for .* to be enabled/)
      end
    end

    it 'makes no check call for submit' do
      allow(native).to receive(:displayed?)
      allow(native).to receive(:enabled?)
      expect(ensure_native(:submit)).to eq(0)
      expect(native).not_to have_received(:displayed?)
      expect(native).not_to have_received(:enabled?)
      expect([appium.script_calls, appium.calls]).to eq([[], []])
    end

    it 'raises a stale element at once rather than waiting out the timeout' do
      Raider.timeout = 5
      allow(native).to receive(:displayed?).and_raise(Selenium::WebDriver::Error::StaleElementReferenceError)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect { ensure_native(:click) }.to raise_error(Selenium::WebDriver::Error::StaleElementReferenceError)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
      expect(native).to have_received(:displayed?).once
    end

    it 'reports the elapsed wait of the gate, not the configured timeout' do
      Raider.timeout = 5
      appium.answer(:element_displayed?, false)
      error = nil
      Raider::Wait.until(timeout: 0.2) do
        ensure_native(:click)
      rescue Raider::NotActionable => e
        error = e
      end
      expect(error.message).to match(/waited 0\.2\d?s for/)
    end

    it 'raises KeyError for an action with no native table entry' do
      expect { ensure_native(:hover) }.to raise_error(KeyError)
    end

    it 'makes one displayed call and no enabled call when forced' do
      allow(native).to receive(:displayed?).and_return(true)
      allow(native).to receive(:enabled?)
      expect(Raider::Actionability.ensure(native, :click, force: true)).to eq(0)
      expect(native).to have_received(:displayed?).once
      expect(native).not_to have_received(:enabled?)
    end

    it 'raises on a stale element when forced' do
      appium.answer(:element_displayed?, Selenium::WebDriver::Error::StaleElementReferenceError)
      expect { Raider::Actionability.ensure(native, :click, force: true) }
        .to raise_error(Selenium::WebDriver::Error::StaleElementReferenceError)
    end

    it 'makes no displayed or enabled call when actionability is off' do
      Raider.actionability = false
      allow(native).to receive(:displayed?)
      allow(native).to receive(:enabled?)
      expect(ensure_native(:click)).to eq(0)
      expect(native).not_to have_received(:displayed?)
      expect(native).not_to have_received(:enabled?)
    end

    it 'asks for the context once per action' do
      appium.answer(:element_displayed?, true).answer(:element_enabled?, true)
      allow(appium).to receive(:current_context).and_call_original
      ensure_native(:click)
      expect(appium).to have_received(:current_context).once
    end

    context 'when the context is a webview' do
      let(:context) { 'WEBVIEW_1' }

      it 'uses the script path as before' do
        appium.script_results.push({ 'check' => 'visible' }, nil)
        expect(ensure_native(:click)).to eq(1)
        expect(appium.script_calls.size).to eq(2)
      end
    end
  end

  it 'prints the notice once' do
    bridge.script_results.push(nil, nil)
    2.times { Raider::Actionability.ensure(element, :click, force: false) }
    expect($stderr).to have_received(:puts).with(/actionability on/).once
  end

  it 'prints no notice with RAIDER_QUIET=1' do
    bridge.script_results.push(nil)
    old = ENV.fetch('RAIDER_QUIET', nil)
    ENV['RAIDER_QUIET'] = '1'
    Raider::Actionability.ensure(element, :click, force: false)
    expect($stderr).not_to have_received(:puts)
  ensure
    old ? ENV['RAIDER_QUIET'] = old : ENV.delete('RAIDER_QUIET')
  end
end
