# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'

RSpec.describe 'Raider.by_role' do
  it 'returns just the role for a bare role' do
    expect(Raider.by_role('button')).to eq(role: ['button'])
  end

  it 'adds the name option' do
    expect(Raider.by_role('button', name: 'Save')).to eq(role: ['button', { name: 'Save' }])
  end

  it 'adds exact and include_hidden only when set' do
    expect(Raider.by_role('link', name: 'Home', exact: true, include_hidden: true))
      .to eq(role: ['link', { name: 'Home', exact: true, include_hidden: true }])
    expect(Raider.by_role('link', include_hidden: true)).to eq(role: ['link', { include_hidden: true }])
  end

  it 'stringifies a symbol role' do
    expect(Raider.by_role(:heading)).to eq(role: ['heading'])
  end

  it 'rejects an unknown role' do
    expect { Raider.by_role('foo') }
      .to raise_error(ArgumentError, "unknown role 'foo'; roles are the ARIA role names such as button, link, textbox")
  end

  it 'rejects a non-String name' do
    expect { Raider.by_role('button', name: /Save/) }.to raise_error(ArgumentError)
  end

  it 'has a frozen ROLES list' do
    expect(Raider::ROLES).to be_frozen.and include('button', 'generic')
  end

  it 'is available on Raider::Helpers' do
    helper = Object.new.extend(Raider::Helpers)
    expect(helper.by_role('tab', name: 'One')).to eq(role: ['tab', { name: 'One' }])
  end
end
