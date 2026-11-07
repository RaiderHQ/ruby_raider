# frozen_string_literal: true

require 'rspec'
require_relative '../support/fake_bridge'
require_relative '../../../lib/ruby_raider/runtime/rspec'

RSpec.describe 'Raider element matchers' do
  include Raider::Matchers

  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:element) { Selenium::WebDriver::Element.new(bridge, 'e1') }
  let(:gone) { Selenium::WebDriver::Error::NoSuchElementError }

  after { Raider.reset }

  describe 'have_text' do
    it 'passes once the text arrives' do
      bridge.answer(:element_text, 'Welcome', 'Welcome back Ann')
      expect(have_text('Welcome back Ann', wait: 1).matches?(element)).to be(true)
    end

    it 'matches a whitespace-normalised substring' do
      bridge.answer(:element_text, "Hi\n  Welcome   back Ann  ")
      expect(have_text('Welcome back', wait: 1).matches?(element)).to be(true)
    end

    it 'fails exact on extra text with the last seen value' do
      bridge.answer(:element_text, 'Welcome back Ann!')
      matcher = have_text('Welcome back Ann', exact: true, wait: 0.2)
      expect(matcher.matches?(element)).to be(false)
      expect(matcher.failure_message)
        .to match(/\A#{Regexp.escape('expected <element> to have exact text "Welcome back Ann", last seen "Welcome back Ann!" after ')}0\.\d+s\z/)
    end

    it 'matches a regexp against the normalised text' do
      bridge.answer(:element_text, "Hi  Ann\n Lee")
      expect(have_text(/Ann Lee/, wait: 1).matches?(element)).to be(true)
      expect(have_text(/Bob/, wait: 0.2).matches?(element)).to be(false)
    end

    it 'words an exact regexp failure' do
      bridge.answer(:element_text, 'Bob')
      matcher = have_text(/Ann/, exact: true, wait: 0.2)
      expect(matcher.matches?(element)).to be(false)
      expect(matcher.failure_message).to start_with('expected <element> to have exact text /Ann/, last seen "Bob"')
    end

    it 'waits for the text to change when negated' do
      bridge.answer(:element_text, 'Loading', 'Loading', 'Done')
      expect(have_text('Loading', wait: 1).does_not_match?(element)).to be(true)
    end

    it 'words the negated failure' do
      bridge.answer(:element_text, 'Loading')
      matcher = have_text('Loading', wait: 0.2)
      expect(matcher.does_not_match?(element)).to be(false)
      expect(matcher.failure_message_when_negated)
        .to match(/\A#{Regexp.escape('expected <element> not to have text "Loading", last seen "Loading" after ')}0\.\d+s\z/)
    end

    it 'reads a template element with timeout: 0 so the wait is not doubled' do
      seen = []
      reader = Object.new
      reader.define_singleton_method(:text) { |timeout: 5| seen << timeout && 'hello' }
      expect(have_text('hello', wait: 1).matches?(reader)).to be(true)
      expect(seen).to eq([0])
    end

    it 'does not pass a timeout to a reader that does not take one' do
      expect(have_text('hello', wait: 1).matches?(Struct.new(:text).new('hello'))).to be(true)
    end
  end

  describe 'have_value' do
    it 'reads the value attribute' do
      bridge.answer(:element_attribute, nil, 'admin')
      expect(have_value('admin', wait: 1).matches?(element)).to be(true)
    end
  end

  describe 'have_value with a regexp' do
    it 'matches the value' do
      bridge.answer(:element_attribute, 'xyz')
      expect(have_value(/y/, wait: 1).matches?(element)).to be(true)
    end
  end

  describe 'have_attribute' do
    it 'passes when the attribute is present' do
      bridge.answer(:element_attribute, nil, '/home')
      expect(have_attribute('href', wait: 1).matches?(element)).to be(true)
    end

    it 'fails when the attribute stays absent' do
      bridge.answer(:element_attribute, nil)
      expect(have_attribute('href', wait: 0.2).matches?(element)).to be(false)
    end

    it 'matches a regexp' do
      bridge.answer(:element_attribute, 'btn', 'btn active')
      expect(have_attribute('class', /active/, wait: 1).matches?(element)).to be(true)
    end

    it 'compares a string by equality' do
      bridge.answer(:element_attribute, 'btn active')
      expect(have_attribute('class', 'btn', wait: 0.2).matches?(element)).to be(false)
    end
  end

  describe 'state matchers' do
    it 'be_visible passes once displayed turns true' do
      bridge.answer(:element_displayed?, false, true)
      expect(be_visible(wait: 1).matches?(element)).to be(true)
    end

    it 'be_hidden passes when the element is absent' do
      bridge.answer(:element_displayed?, gone)
      expect(be_hidden(wait: 0.2).matches?(element)).to be(true)
    end

    it 'be_hidden passes when not displayed' do
      bridge.answer(:element_displayed?, false)
      expect(be_hidden(wait: 0.2).matches?(element)).to be(true)
    end

    it 'be_hidden fails on a visible element with the last seen state' do
      bridge.answer(:element_displayed?, true)
      matcher = be_hidden(wait: 0.2)
      expect(matcher.matches?(element)).to be(false)
      expect(matcher.failure_message).to match(/\A#{Regexp.escape('expected <element> to be hidden, last seen visible after ')}0\.\d+s\z/)
    end

    it 'be_visible failure reads last seen hidden' do
      bridge.answer(:element_displayed?, false)
      matcher = be_visible(wait: 0.2)
      expect(matcher.matches?(element)).to be(false)
      expect(matcher.failure_message).to match(/\A#{Regexp.escape('expected <element> to be visible, last seen hidden after ')}0\.\d+s\z/)
    end

    it 'be_enabled and be_disabled read enabled?' do
      bridge.answer(:element_enabled?, false, true)
      expect(be_enabled(wait: 1).matches?(element)).to be(true)
      bridge.answer(:element_enabled?, false)
      expect(be_disabled(wait: 1).matches?(element)).to be(true)
    end

    it 'be_checked reads selected?' do
      bridge.answer(:element_selected?, false, true)
      expect(be_checked(wait: 1).matches?(element)).to be(true)
    end

    it 'be_checked failure reads last seen unchecked' do
      bridge.answer(:element_selected?, false)
      matcher = be_checked(wait: 0.2)
      expect(matcher.matches?(element)).to be(false)
      expect(matcher.failure_message).to match(/\A#{Regexp.escape('expected <element> to be checked, last seen unchecked after ')}0\.\d+s\z/)
    end
  end

  describe 'absence and staleness' do
    it 'not_to be_visible passes on an absent element' do
      bridge.answer(:element_displayed?, gone)
      expect(be_visible(wait: 1).does_not_match?(element)).to be(true)
    end

    it 'not_to be_visible passes on a stale raw element' do
      bridge.answer(:element_displayed?, Selenium::WebDriver::Error::StaleElementReferenceError)
      expect(be_visible(wait: 1).does_not_match?(element)).to be(true)
    end

    it 'be_visible keeps retrying an absent element and fails' do
      bridge.answer(:element_displayed?, gone)
      matcher = be_visible(wait: 0.2)
      expect(matcher.matches?(element)).to be(false)
      expect(matcher.failure_message).to include('last seen: not found')
    end

    it 'fails at once with the hint for a stale raw element' do
      bridge.answer(:element_text, Selenium::WebDriver::Error::StaleElementReferenceError)
      matcher = have_text('x', wait: 5)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(matcher.matches?(element)).to be(false)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
      expect(matcher.failure_message).to eq(
        'expected <element> to have text "x", but the element is stale; re-find it, ' \
        'use the block form, or a page-object element'
      )
    end

    it 'be_hidden passes on a stale raw element' do
      bridge.answer(:element_displayed?, Selenium::WebDriver::Error::StaleElementReferenceError)
      expect(be_hidden(wait: 1).matches?(element)).to be(true)
    end

    it 'retries a stale element read through a block' do
      bridge.answer(:element_text, Selenium::WebDriver::Error::StaleElementReferenceError, 'x')
      expect(have_text('x', wait: 1).matches?(proc { element })).to be(true)
    end

    it 'composes with and' do
      bridge.answer(:element_text, 'abc')
      bridge.answer(:element_displayed?, true)
      expect(element).to have_text('a', wait: 1).and be_visible(wait: 1)
    end
  end

  it 'works through expect syntax with a block' do
    bridge.answer(:element_text, 'x')
    expect { element }.to have_text('x', wait: 1)
  end
end
