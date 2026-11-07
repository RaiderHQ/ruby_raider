# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime'
require_relative '../support/browser'

RSpec.describe 'Raider actionability script in a real browser', :browser do
  let(:driver) { Raider::Spec::Browser.driver }
  let(:click) { Raider::Actionability::CHECKS[:click] }
  let(:send_keys) { Raider::Actionability::CHECKS[:send_keys] }

  before { Raider::Spec::Browser.open('actionability.html') }

  after(:all) { Raider::Spec::Browser.quit } # rubocop:disable RSpec/BeforeAfterAll

  def element(id)
    driver.find_element(id: id)
  end

  def run(id, checks)
    driver.execute_script(Raider::Actionability::SCRIPT, element(id), checks)
  end

  # Stable needs a previous poll to compare with, so poll twice like the gate does.
  def settled(id, checks)
    run(id, checks)
    run(id, checks)
  end

  it 'passes a plain button once it has been polled twice' do
    expect(run('plain', click)).to eq('check' => 'stable', 'first' => true)
    expect(run('plain', click)).to be_nil
  end

  it 'fails visible for display: none and visibility: hidden' do
    expect(run('hidden-display', click)).to eq('check' => 'visible')
    expect(run('hidden-visibility', click)).to eq('check' => 'visible')
  end

  it 'scrolls an off-screen button into view and passes' do
    expect(settled('far', click)).to be_nil
  end

  it 'reports the overlay covering a button with integer coordinates' do
    result = settled('covered', click)
    expect(result['check']).to eq('events')
    expect(result['covering']['element']).to eq('div#overlay')
    expect(result['covering']['x']).to be_a(Integer)
    expect(result['covering']['y']).to be_a(Integer)
  end

  it 'reports the sticky header covering a button after the script scrolls' do
    result = settled('under-header', click)
    expect(result['check']).to eq('events')
    expect(result['covering']['element']).to eq('header#top')
  end

  it 'fails enabled for a disabled button and a button in a disabled fieldset' do
    expect(run('disabled', click)).to eq('check' => 'enabled')
    expect(run('in-fieldset', click)).to eq('check' => 'enabled')
  end

  it 'treats the first legend of a disabled fieldset as enabled' do
    expect(settled('legend-button', click)).to be_nil
  end

  it 'fails editable for a readonly input and passes a writable one and contenteditable' do
    expect(run('readonly', send_keys)).to eq('check' => 'editable')
    expect(run('writable', send_keys)).to be_nil
    expect(run('area', send_keys)).to be_nil
    expect(run('editable', send_keys)).to be_nil
  end

  it 'passes editable for a button and the body, which keys such as Enter and Escape target' do
    expect(run('plain', send_keys)).to be_nil
    expect(driver.execute_script(Raider::Actionability::SCRIPT, driver.find_element(tag_name: 'body'), send_keys)).to be_nil
  end

  it 'fails inert inside an [inert] region' do
    expect(run('in-inert', click)).to eq('check' => 'inert')
  end

  it 'fails inert outside an open modal dialog and passes inside it' do
    driver.execute_script("document.getElementById('dlg').showModal()")
    expect(run('outside-dialog', click)).to eq('check' => 'inert')
    expect(settled('in-dialog', click)).to be_nil
  end

  it 'reports a moving button as not stable on consecutive polls' do
    expect(run('moving', click)).to eq('check' => 'stable', 'first' => true)
    sleep 0.1
    expect(run('moving', click)).to eq('check' => 'stable')
    sleep 0.1
    expect(run('moving', click)).to eq('check' => 'stable')
  end

  it 'reports an element moving vertically in a scrollable page as not stable' do
    expect(run('bouncer', click)).to eq('check' => 'stable', 'first' => true)
    sleep 0.1
    expect(run('bouncer', click)).to eq('check' => 'stable')
    sleep 0.1
    expect(run('bouncer', click)).to eq('check' => 'stable')
  end

  it 'passes a static button on the second poll' do
    run('plain', click)
    sleep 0.1
    expect(run('plain', click)).to be_nil
  end

  it 'passes editable for a select' do
    expect(run('choices', send_keys)).to be_nil
  end

  it 'fails visible for a file input inside a display: none container, except when typing a path' do
    expect(run('file-hidden', %w[visible])).to eq('check' => 'visible')
    expect(run('file-hidden', click)).to eq('check' => 'visible')
    expect(run('file-hidden', send_keys)).to be_nil
  end

  it 'fails visible for a zero-sized button' do
    expect(run('zero', click)).to eq('check' => 'visible')
  end

  it 'scrolls a button clipped inside an overflow container into view' do
    expect(settled('deep', click)).to be_nil
  end

  it 'passes inert for a button in a shadow root inside the open modal dialog' do
    driver.execute_script("document.getElementById('dlg').showModal()")
    button = driver.execute_script("return document.getElementById('shadow-host').shadowRoot.getElementById('shadow-button')")
    driver.execute_script(Raider::Actionability::SCRIPT, button, click)
    expect(driver.execute_script(Raider::Actionability::SCRIPT, button, click)).to be_nil
  end

  it 'skips stable and events for an option' do
    expect(run('opt-a', click)).to be_nil
  end

  it 'passes visible for a file input with an empty rect' do
    expect(run('file', %w[visible])).to be_nil
  end

  it 'keeps the previous rect in a WeakMap and not on the element' do
    run('plain', click)
    expect(driver.execute_script('return typeof window.__raiderRects')).to eq('object')
    expect(driver.execute_script("return '__raiderRect' in document.getElementById('plain')")).to be(false)
    expect(driver.execute_script('return window.__raider === undefined')).to be(true)
  end
end
