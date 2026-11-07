# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../../../lib/ruby_raider/runtime/rspec'
require_relative '../support/fake_bridge'

RSpec.describe 'Raider presence matchers' do
  include Raider::Matchers

  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:driver) { Raider::Spec.driver(bridge) }

  before { Raider.timeout = 0.3 }

  after { Raider.reset }

  it 'passes on the second poll once the element appears' do
    bridge.enqueue([])
    bridge.enqueue(['e'])
    expect(driver).to have_element(id: 'x')
    expect(bridge.calls.count { |call| call.first == :find_elements_by }).to eq(2)
  end

  it 'passes a negated expectation on the first poll when nothing matches' do
    expect(driver).not_to have_element(id: 'x')
    expect(bridge.calls.count { |call| call.first == :find_elements_by }).to eq(1)
  end

  it 'names the locator and the last count on failure' do
    matcher = have_element({ id: 'x' }, wait: 0.1)
    expect(matcher.matches?(driver)).to be(false)
    expect(matcher.failure_message).to match(/to have element .*id: "x".*last seen 0/)
  end

  it 'builds a css locator from have_css' do
    expect(have_css('.row').expected).to eq({ css: '.row' })
  end

  it 'builds an xpath locator from have_xpath' do
    expect(have_xpath('//p', wait: 1).expected).to eq({ xpath: '//p' })
  end
end
