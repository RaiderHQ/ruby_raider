# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider::Actionable' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:element) { Selenium::WebDriver::Element.new(bridge, 'e1') }
  let(:keys) { Selenium::WebDriver::Keys.encode(['a', :enter]) }

  before do
    Raider.reset
    Raider::Actionability.reset_notice
    allow($stderr).to receive(:puts)
  end

  after { Raider.reset }

  it 'is prepended to Selenium::WebDriver::Element' do
    expect(Selenium::WebDriver::Element.ancestors.first).to eq(Raider::Actionable)
  end

  it 'defines only the four action methods' do
    expect(Raider::Actionable.instance_methods(false)).to contain_exactly(:click, :send_keys, :clear, :submit)
  end

  it 'polls the script until it passes, then clicks' do
    bridge.script_results.push({ 'check' => 'visible' }, nil)
    element.click
    expect([bridge.script_calls.size, bridge.calls.last]).to eq([2, [:click_element, 'e1']])
  end

  it 'clicks after one tag_name command when forced' do
    element.click(force: true)
    expect([bridge.script_calls, bridge.calls]).to eq([[], [[:element_tag_name, 'e1'], [:click_element, 'e1']]])
  end

  it 'sends the keys Selenium would send' do
    bridge.script_results.push(nil)
    element.send_keys('a', :enter)
    expect(bridge.calls.last).to eq([:send_keys_to_element, 'e1', keys])
  end

  it 'sends keys when forced without leaking the keyword' do
    element.send_keys('a', :enter, force: true)
    expect(bridge.calls.last).to eq([:send_keys_to_element, 'e1', keys])
  end

  it 'clears after the check' do
    bridge.script_results.push(nil)
    element.clear
    expect([bridge.script_calls.size, bridge.calls.last]).to eq([1, [:clear_element, 'e1']])
  end

  it 'submits after the check' do
    bridge.script_results.push(nil)
    element.submit
    expect([bridge.script_calls.size, bridge.calls.last]).to eq([1, [:submit_element, 'e1']])
  end

  it 'makes no script call when actionability is off' do
    Raider.actionability = false
    element.click
    expect([bridge.script_calls, bridge.calls]).to eq([[], [[:click_element, 'e1']]])
  end

  it 'raises a stale element at once without acting' do
    stale = Class.new(Raider::Spec::FakeBridge) do
      def execute_script(*) = raise(Selenium::WebDriver::Error::StaleElementReferenceError, 'stale')
    end.new
    expect { Selenium::WebDriver::Element.new(stale, 'e1').click }
      .to raise_error(Selenium::WebDriver::Error::StaleElementReferenceError)
    expect(stale.calls).to be_empty
  end

  it 'lets a script timeout from the page propagate' do
    hung = Class.new(Raider::Spec::FakeBridge) do
      def execute_script(*) = raise(Selenium::WebDriver::Error::ScriptTimeoutError, 'hung')
    end.new
    expect { Selenium::WebDriver::Element.new(hung, 'e1').click }
      .to raise_error(Selenium::WebDriver::Error::ScriptTimeoutError)
  end

  it 'gates subclasses such as the Appium element' do
    appium_like = Class.new(Selenium::WebDriver::Element)
    stub_const('AppiumLikeElement', appium_like)
    bridge.script_results.push(nil)
    appium_like.new(bridge, 'e1').click
    expect([bridge.script_calls.size, bridge.calls.last]).to eq([1, [:click_element, 'e1']])
  end
end
