# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime/context'

RSpec.describe 'Raider::Context' do
  let(:appium_bridge_class) do
    stub_const('Appium::Core::Base::Bridge', Class.new(Selenium::WebDriver::Remote::Bridge))
  end

  def appium_bridge(context)
    bridge = appium_bridge_class.allocate
    bridge.define_singleton_method(:current_context) { context }
    bridge
  end

  def plain_bridge
    bridge = Selenium::WebDriver::Remote::Bridge.allocate
    bridge.define_singleton_method(:current_context) { raise 'current_context must not be asked' }
    bridge
  end

  def holder(klass, bridge)
    klass.allocate.tap { |object| object.instance_variable_set(:@bridge, bridge) }
  end

  describe '.web?' do
    it 'is false on an Appium NATIVE_APP context' do
      expect(Raider::Context.web?(appium_bridge('NATIVE_APP'))).to be(false)
    end

    it 'is true on an Appium webview context' do
      expect(Raider::Context.web?(appium_bridge('WEBVIEW_1'))).to be(true)
    end

    it 'is true on an Appium CHROMIUM context' do
      expect(Raider::Context.web?(appium_bridge('CHROMIUM'))).to be(true)
    end

    it 'is true for a non-Appium bridge without asking current_context' do
      expect(Raider::Context.web?(plain_bridge)).to be(true)
    end

    it 'is true for a non-Appium bridge when Appium is not loaded' do
      expect(Raider::Context.web?(Object.new)).to be(true)
    end
  end

  describe '.web_for?' do
    it 'reads the bridge of a driver' do
      driver = Selenium::WebDriver::Driver
      expect(Raider::Context.web_for?(holder(driver, appium_bridge('NATIVE_APP')))).to be(false)
      expect(Raider::Context.web_for?(holder(driver, appium_bridge('WEBVIEW_1')))).to be(true)
      expect(Raider::Context.web_for?(holder(driver, plain_bridge))).to be(true)
    end

    it 'reads the bridge of an element' do
      element = Selenium::WebDriver::Element
      expect(Raider::Context.web_for?(holder(element, appium_bridge('NATIVE_APP')))).to be(false)
      expect(Raider::Context.web_for?(holder(element, appium_bridge('CHROMIUM')))).to be(true)
      expect(Raider::Context.web_for?(holder(element, plain_bridge))).to be(true)
    end

    it 'is true when the object has no bridge' do
      expect(Raider::Context.web_for?(Object.new)).to be(true)
    end
  end
end
