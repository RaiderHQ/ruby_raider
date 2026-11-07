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

  it 'makes no script call on an Appium native context' do
    appium = Class.new(Raider::Spec::FakeBridge) { def current_context = 'NATIVE_APP' }.new
    native = Selenium::WebDriver::Element.new(appium, 'e1')
    Raider::Actionability.ensure(native, :click, force: false)
    expect(appium.script_calls).to be_empty
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
