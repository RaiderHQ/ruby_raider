# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime'
require_relative 'support/fake_bridge'

RSpec.describe 'Raider::Observer' do
  let(:bridge) { Raider::Spec::FakeBridge.new }
  let(:driver) { Raider::Spec.driver(bridge) }
  let(:recorder_class) do
    Class.new do
      attr_reader :events

      def initialize = @events = []

      def action_started(**details)
        @events << [:action_started, details]
        :token
      end

      def action_ready(token, **details) = @events << [:action_ready, token, details]
      def action_finished(token, **details) = @events << [:action_finished, token, details]
    end
  end
  let(:recorder) { recorder_class.new }

  before do
    Raider.reset
    Raider::Actionability.reset_notice
    allow($stderr).to receive(:puts)
    allow(Raider::Describe).to receive(:element) { |element| "<el #{element.ref.last}>" }
    Raider.observer = recorder
  end

  after { Raider.reset }

  def names = recorder.events.map(&:first)
  def finished = recorder.events.last.last

  it 'reports a role click with its retries' do
    bridge.script_results.push([Selenium::WebDriver::Element.new(bridge, 'a')])
    button = driver.find_element(Raider.by_role('button', name: 'Save'))
    bridge.script_results.push({ 'check' => 'stable', 'first' => false }, { 'check' => 'stable', 'first' => false }, nil)
    button.click
    started, ready, done = recorder.events
    expect(started).to eq([:action_started, { action: :click, locator: { strategy: 'role', selector: 'button, name: Save' }, within: [], args: nil }])
    expect(ready).to eq([:action_ready, :token, { element: button }])
    expect(done[1]).to eq(:token)
    expect(done[2]).to include(status: :passed, retries: 2, error: nil, element: button)
    expect(done[2][:waited_ms]).to be_a(Integer)
  end

  it 'hands the observer a frozen copy of the keys so it cannot change what is typed' do
    keys = ['a']
    seen = nil
    recorder.define_singleton_method(:action_started) { |**details| (seen = details[:args]) << 'evil' }
    bridge.enqueue(['f'])
    driver.find_element(id: 'x').send_keys(*keys)
    expect(seen).to be_frozen
    expect(bridge.calls.select { |call| call.first == :send_keys_to_element }.map(&:last)).to eq([['a']])
  end

  it 'reports a nested send_keys with its within chain and keys' do
    bridge.enqueue(['f'])
    form = driver.find_element(css: 'form')
    bridge.enqueue(['i'])
    field = form.find_element(id: 'email')
    bridge.script_results.push(nil)
    field.send_keys('a')
    expect(recorder.events.first.last).to eq(
      action: :send_keys, locator: { strategy: 'id', selector: 'email' },
      within: [{ strategy: 'css', selector: 'form' }], args: ['a']
    )
  end

  it 'reports clear and submit with nil args' do
    bridge.enqueue(['a'])
    el = driver.find_element(name: 'q')
    bridge.script_results.push(nil, nil)
    el.clear
    el.submit
    expect(recorder.events.select { |e| e.first == :action_started }.map { |e| [e.last[:action], e.last[:args]] })
      .to eq([[:clear, nil], [:submit, nil]])
  end

  it 'reports a failed timeout with the error and re-raises it' do
    Raider.timeout = 0.3
    bridge.enqueue(['a'])
    el = driver.find_element(id: 'x')
    bridge.script_results.concat([{ 'check' => 'visible' }] * 50)
    expect { el.click }.to raise_error(Raider::NotActionable) { |error|
      expect(finished).to include(status: :failed, error: error)
      expect(finished[:retries]).to eq(error.retries)
      expect(error.retries).to be >= 1
    }
    expect(names).to eq(%i[action_started action_finished])
  end

  it 're-raises a non-StandardError after reporting it' do
    el = Selenium::WebDriver::Element.new(bridge, 'e1')
    bridge.script_results.push(Interrupt.new('stop'))
    expect { el.click }.to raise_error(Interrupt)
    expect(finished).to include(status: :failed)
    expect(finished[:error]).to be_a(Interrupt)
  end

  it 'still reports with force: true' do
    bridge.answer(:element_tag_name, 'div')
    Selenium::WebDriver::Element.new(bridge, 'e1').click(force: true)
    expect(names).to eq(%i[action_started action_ready action_finished])
    expect(finished).to include(status: :passed, retries: 0)
  end

  it 'still reports with actionability off' do
    Raider.actionability = false
    Selenium::WebDriver::Element.new(bridge, 'e1').click
    expect(names).to eq(%i[action_started action_ready action_finished])
  end

  it 'still reports a native click' do
    appium = Class.new(Raider::Spec::FakeBridge) { def current_context = 'NATIVE_APP' }.new
    appium.answer(:element_displayed?, false, true).answer(:element_enabled?, true)
    Selenium::WebDriver::Element.new(appium, 'e1').click
    expect(names).to eq(%i[action_started action_ready action_finished])
    expect(finished[:retries]).to eq(1)
  end

  it 'gives a nil locator to an unstamped element' do
    bridge.answer(:element_tag_name, 'div')
    Selenium::WebDriver::Element.new(bridge, 'e1').click(force: true)
    expect(recorder.events.first.last).to include(locator: nil, within: [])
  end

  it 'lets the click happen when the observer raises, prints once and clears it' do
    recorder.define_singleton_method(:action_started) { |**| raise ArgumentError, 'boom' }
    bridge.answer(:element_tag_name, 'div')
    Selenium::WebDriver::Element.new(bridge, 'e1').click(force: true)
    expect(bridge.calls.last).to eq([:click_element, 'e1'])
    expect($stderr).to have_received(:puts).with('[raider] observer stopped: ArgumentError: boom').once
    expect(Raider.observer).to be_nil
  end

  it 'passes the token the observer returned back to later events' do
    bridge.answer(:element_tag_name, 'div')
    Selenium::WebDriver::Element.new(bridge, 'e1').click(force: true)
    expect(recorder.events.map { |e| e[1] }.drop(1)).to eq(%i[token token])
  end

  describe 'a broken observer' do
    let(:element) { Selenium::WebDriver::Element.new(bridge, 'e1') }

    before { bridge.answer(:element_tag_name, 'div') }

    [NotImplementedError, SystemStackError, ArgumentError].each do |klass|
      %i[action_started action_ready action_finished].each do |hook|
        it "survives #{klass} in #{hook}: the click happens, one line, observer cleared" do
          recorder.define_singleton_method(hook) { |*, **| raise klass, 'boom' }
          element.click(force: true)
          expect(bridge.calls.last).to eq([:click_element, 'e1'])
          expect($stderr).to have_received(:puts).with("[raider] observer stopped: #{klass}: boom").once
          expect(Raider.observer).to be_nil
        end
      end
    end

    it 'lets an Interrupt from the observer propagate' do
      recorder.define_singleton_method(:action_started) { |**| raise Interrupt }
      expect { element.click(force: true) }.to raise_error(Interrupt)
    end

    it 'truncates the message to its first line and 200 characters' do
      recorder.define_singleton_method(:action_started) { |**| raise ArgumentError, "#{'x' * 500}\nsecond" }
      element.click(force: true)
      expect($stderr).to have_received(:puts).with("[raider] observer stopped: ArgumentError: #{'x' * 200}")
    end

    it 'survives an exception whose message raises' do
      error = Class.new(StandardError) { def message = raise('no') }
      recorder.define_singleton_method(:action_started) { |**| raise error }
      expect { element.click(force: true) }.not_to raise_error
      expect(Raider.observer).to be_nil
    end

    it 'leaves a replacement observer installed' do
      other = recorder_class.new
      recorder.define_singleton_method(:action_started) do |**|
        Raider.observer = other
        raise 'swap'
      end
      element.click(force: true)
      expect(Raider.observer).to equal(other)
    end

    it 'does not report again for an action taken inside a hook' do
      inner = Selenium::WebDriver::Element.new(bridge, 'e2')
      started = 0
      recorder.define_singleton_method(:action_started) do |**|
        started += 1
        inner.click(force: true)
        :token
      end
      element.click(force: true)
      expect(bridge.calls.select { |c| c.first == :click_element }).to eq([[:click_element, 'e2'], [:click_element, 'e1']])
      expect(started).to eq(1)
    end

    it 'sends no follow-up events when action_started returns nil' do
      events = []
      recorder.define_singleton_method(:action_started) { |**| nil }
      recorder.define_singleton_method(:action_ready) { |*, **| events << :ready }
      recorder.define_singleton_method(:action_finished) { |*, **| events << :finished }
      element.click(force: true)
      expect(events).to be_empty
    end
  end

  describe 'stamping' do
    it 'shares one frozen stamp across a find_elements result' do
      bridge.enqueue(%w[a b c])
      stamps = driver.find_elements(id: 'x').map { |e| e.instance_variable_get(:@raider_locator) }
      expect(stamps.map(&:object_id).uniq.size).to eq(1)
      expect([stamps.first.frozen?, stamps.first[:within].frozen?]).to eq([true, true])
    end

    it 'deep-freezes the stamp and keeps the caller string out of it' do
      bridge.enqueue(['a'])
      selector = +'#login'
      stamp = driver.find_element(css: selector).instance_variable_get(:@raider_locator)
      expect([stamp[:strategy].frozen?, stamp[:selector].frozen?]).to eq([true, true])
      expect(stamp[:selector]).not_to equal(selector)
      selector << '-changed'
      expect(stamp[:selector]).to eq('#login')
    end

    it 'leaves a frozen element unstamped without raising' do
      element = Selenium::WebDriver::Element.new(bridge, 'a').freeze
      expect(Raider::Observer.stamp(element, [{ id: 'x' }], driver)).to equal(element)
      expect(Raider::Observer.locator_of(element)).to be_nil
    end

    it 'chains three levels, outermost first' do
      %w[m f i].each { |id| bridge.enqueue([id]) }
      field = driver.find_element(css: 'main').find_element(css: 'form').find_element(id: 'email')
      expect(Raider::Observer.locator_of(field)[:within]).to eq(
        [{ strategy: 'css', selector: 'main' }, { strategy: 'css', selector: 'form' }]
      )
    end

    it 'stamps through the first alias' do
      bridge.enqueue(['a'])
      expect(Raider::Observer.locator_of(driver.first(id: 'x'))).to include(strategy: 'id', selector: 'x')
    end

    it 'takes the first item of an Array-form selector through a real find' do
      bridge.enqueue(['a'])
      found = driver.find_element(text: ['Save', { exact: true }])
      expect(Raider::Observer.locator_of(found)).to include(strategy: 'text', selector: 'Save')
    end
  end

  describe 'Raider.report' do
    it 'returns nil without an observer or when the hook is missing' do
      Raider.observer = Object.new
      expect(Raider.report(:nothing)).to be_nil
      Raider.observer = nil
      expect(Raider.report(:nothing) { raise 'not built' }).to be_nil
    end

    it 'builds the details from the block only for an observer that responds' do
      seen = nil
      Raider.observer = Object.new.tap { |o| o.define_singleton_method(:hook) { |first, **d| seen = [first, d] } }
      Raider.report(:hook, 1) { { a: 2 } }
      expect(seen).to eq([1, { a: 2 }])
    end

    it 'catches a failing block under the same rescue' do
      Raider.observer = recorder
      Raider.report(:action_started) { raise 'bad' }
      expect($stderr).to have_received(:puts).with('[raider] observer stopped: RuntimeError: bad')
      expect(Raider.observer).to be_nil
    end
  end

  describe 'with no observer' do
    before { Raider.observer = nil }

    it 'sends the same bridge commands as a bare click' do
      bridge.script_results.push({ 'check' => 'visible' }, nil)
      Selenium::WebDriver::Element.new(bridge, 'e1').click
      expect(bridge.calls).to eq([[:click_element, 'e1']])
      expect(bridge.script_calls.size).to eq(2)
    end

    it 'yields without a run' do
      expect { |block| Raider::Observer.emit_action(nil, :click, &block) }.to yield_with_args(nil)
    end
  end

  describe '.locator_of' do
    # Straight through the stamp: Selenium rejects some of these spellings before any find succeeds.
    def locate(*args)
      element = Selenium::WebDriver::Element.new(bridge, 'a')
      Raider::Observer.locator_of(Raider::Observer.stamp(element, args, driver))
    end

    {
      [:css_selector, 'a'] => %w[css a], [{ class: 'k' }] => %w[class_name k], [{ link: 'l' }] => %w[link_text l],
      [:partial_link, 'p'] => %w[partial_link_text p], ['class name', 'k'] => %w[class_name k],
      ['css selector', 'a'] => %w[css a], ['link text', 'l'] => %w[link_text l],
      ['partial link text', 'p'] => %w[partial_link_text p], ['tag name', 'div'] => %w[tag_name div],
      [:id, 'x'] => %w[id x], [{ xpath: '//a' }] => ['xpath', '//a'], [{ label: 'Email' }] => %w[label Email],
      [{ test_id: 't' }] => %w[test_id t], [{ text: ['Hi', { exact: true }] }] => %w[text Hi]
    }.each do |args, (strategy, selector)|
      it "normalises #{args.inspect}" do
        expect(locate(*args)).to eq(strategy: strategy, selector: selector, within: [])
      end
    end

    it 'renders a role with its options' do
      expect(locate(role: ['button', { name: 'Save', exact: true }])[:selector]).to eq('button, name: Save, exact: true')
    end

    it 'renders a bare role' do
      expect(locate(role: 'button')).to include(strategy: 'role', selector: 'button')
    end

    it 'stamps find_elements results too' do
      bridge.enqueue(%w[a b])
      found = driver.find_elements(id: 'x')
      expect(found.map { |e| Raider::Observer.locator_of(e) }).to all(include(strategy: 'id', selector: 'x'))
    end

    it 'returns nil for an unstamped element' do
      expect(Raider::Observer.locator_of(Selenium::WebDriver::Element.new(bridge, 'e1'))).to be_nil
    end
  end

  it 'names the runtime directory as LIB_DIR' do
    expect(Raider::Observer::LIB_DIR).to eq(File.expand_path('../../lib/ruby_raider/runtime', __dir__))
  end
end
