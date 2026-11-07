# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider::RoleQuery' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:elements) { %w[a b] }
  let(:missing) { Selenium::WebDriver::Error::JavascriptError.new('ReferenceError: window.__raider is undefined') }

  it 'queries once when the engine is already installed' do
    bridge.script_results << elements
    expect(Raider::RoleQuery.run(bridge, nil, 'button', {})).to eq(elements)
    expect(bridge.script_calls.length).to eq(1)
    expect(bridge.script_calls.first.first).to eq(Raider::RoleFinder::QUERY)
  end

  it 'installs the engine once and re-runs the query when it is missing' do
    bridge.script_results.push(missing, elements)
    expect(Raider::RoleQuery.run(bridge, nil, 'button', {})).to eq(elements)
    expect(bridge.script_calls.length).to eq(2)
    expect(bridge.script_calls.last.first).to start_with(Raider::RoleFinder::ENGINE)
    expect(bridge.script_calls.last.first).to end_with(Raider::RoleFinder::QUERY)
  end

  it 'does not retry beyond the install run' do
    bridge.script_results.push(missing, missing)
    expect { Raider::RoleQuery.run(bridge, nil, 'button', {}) }
      .to raise_error(Selenium::WebDriver::Error::JavascriptError)
    expect(bridge.script_calls.length).to eq(2)
  end

  it 'propagates an unrelated JavascriptError' do
    bridge.script_results << Selenium::WebDriver::Error::JavascriptError.new('TypeError: boom')
    expect { Raider::RoleQuery.run(bridge, nil, 'button', {}) }
      .to raise_error(Selenium::WebDriver::Error::JavascriptError, /boom/)
    expect(bridge.script_calls.length).to eq(1)
  end

  it 'passes the scope, role and camelCase options' do
    bridge.script_results << elements
    Raider::RoleQuery.run(bridge, :scope, 'link', name: 'Save', exact: true, include_hidden: true)
    expect(bridge.script_calls.first.drop(1))
      .to eq([:scope, 'link', { 'name' => 'Save', 'exact' => true, 'includeHidden' => true }])
  end

  it 'always carries all three option keys' do
    bridge.script_results << elements
    Raider::RoleQuery.run(bridge, nil, 'link', {})
    expect(bridge.script_calls.first.last).to eq('name' => nil, 'exact' => false, 'includeHidden' => false)
  end

  it 'exposes the engine source as a frozen string' do
    expect(Raider::RoleFinder::ENGINE).to be_frozen.and include('__raider')
  end
end
