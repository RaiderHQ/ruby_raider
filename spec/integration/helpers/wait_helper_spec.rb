# frozen_string_literal: true

require_relative 'wait_helper_support'

WaitHelperSpec.load_templates(mobile: false)

module WaitHelperSpec
  class Page
    include WaitHelper

    attr_reader :driver

    def initialize(driver)
      @driver = driver
    end
  end

  # A <select> answering Support::Select's option queries.
  class FakeSelect < FakeElement
    OPTIONS = [%w[Red red], %w[Blue blue], %w[Green green]].freeze

    def initialize(**state)
      super(tag_name: 'select', **state)
      @options = OPTIONS.each_with_index.map do |(label, value), index|
        FakeElement.new(text: label, attributes: { 'value' => value }, index:)
      end
    end

    attr_reader :options

    def find_elements(xpath: nil, tag_name: nil, **locator)
      return super(**locator) unless xpath || tag_name
      return @options if tag_name

      text = xpath[/normalize-space\(\.\) = "(.*)"\]/, 1]
      value = xpath[/@value = "(.*)"\]/, 1]
      @options.select { |option| option.text == text || option.attribute('value') == value }
    end
  end
end

describe 'WaitHelper' do
  let(:driver) { WaitHelperSpec::FakeDriver.new }
  let(:page) { WaitHelperSpec::Page.new(driver) }

  def element(**state) = WaitHelperSpec::FakeElement.new(**state)
  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  def errors = Selenium::WebDriver::Error

  describe '#find_element' do
    it 'returns the element once it is present and visible' do
      found = element
      driver.script({ id: 'x' }, nil, element(displayed: false), found)
      expect(page.find_element({ id: 'x' }, timeout: 1)).to eq(found)
      expect(driver.finds.size).to eq(3)
    end

    it 'returns a hidden element with visible: false' do
      hidden = element(displayed: false)
      driver.script({ id: 'x' }, hidden)
      expect(page.find_element({ id: 'x' }, visible: false, timeout: 1)).to eq(hidden)
    end

    it 'symbolizes a string-keyed locator' do
      driver.script({ id: 'x' }, element)
      page.find_element({ 'id' => 'x' }, timeout: 1)
      expect(driver.finds).to eq([{ id: 'x' }])
    end

    it 'raises ArgumentError at once for an empty or a two-key locator' do
      started = clock
      expect { page.find_element({}) }.to raise_error(ArgumentError)
      expect { page.find_element({ id: 'a', css: 'b' }) }.to raise_error(ArgumentError)
      expect(clock - started).to be < 0.1
    end

    it 'makes one attempt at timeout: 0' do
      driver.script({ id: 'hidden' }, element(displayed: false))
      expect { page.find_element({ id: 'hidden' }, timeout: 0) }
        .to raise_error(WaitHelper::TimeoutError, /last seen: present but not visible/)
      expect(driver.finds.size).to eq(1)
    end
  end

  describe '#find_elements' do
    it 'returns every match, hidden ones included, once one is present' do
      shown = element
      hidden = element(displayed: false)
      driver.script_many({ css: 'li' }, [], [shown, hidden])
      expect(page.find_elements({ css: 'li' }, timeout: 1)).to eq([shown, hidden])
    end

    it 'returns [] at the timeout without raising' do
      expect(page.find_elements({ css: 'li' }, timeout: 0.2)).to eq([])
    end
  end

  describe '#click' do
    it 'waits through not found, hidden, disabled and moving, then clicks once' do
      target = element(rects: [[0, 0, 10, 10], [5, 5, 10, 10], [5, 5, 10, 10]])
      driver.script({ id: 'go' }, nil, element(displayed: false), element(enabled: false), target)
      page.click({ id: 'go' }, timeout: 2)
      expect(target.log).to eq([[:click]])
      expect(driver.finds.size).to eq(6)
    end

    it 'retries intercepted, stale and not-interactable clicks, re-finding by locator' do
      target = element(errors: [errors::ElementClickInterceptedError.new('covered'),
                                errors::StaleElementReferenceError.new('stale'),
                                errors::ElementNotInteractableError.new('not interactable')])
      driver.script({ id: 'go' }, target)
      page.click({ id: 'go' }, timeout: 3)
      expect(target.log).to eq([[:click]])
      expect(driver.finds.size).to be > 3
    end

    it 'raises InvalidSelectorError on the first attempt' do
      driver.script({ css: '[[' }, errors::InvalidSelectorError)
      expect { page.click({ css: '[[' }, timeout: 1) }.to raise_error(errors::InvalidSelectorError)
      expect(driver.finds.size).to eq(1)
    end

    it 'resolves a per-OS locator with appium_device' do
      android = WaitHelperSpec::FakeDriver.new(device: :android)
      android.script({ accessibility_id: 'b' }, element)
      per_os = { ios: { accessibility_id: 'a' }, android: { accessibility_id: 'b' } }
      WaitHelperSpec::Page.new(android).click(per_os, timeout: 1)
      expect(android.finds.uniq).to eq([{ accessibility_id: 'b' }])
    end

    it 'raises a stale passed element at once, suggesting a locator' do
      passed = element
      passed.go_stale
      expect { page.click(passed, timeout: 2) }.to raise_error(errors::StaleElementReferenceError, /pass .*locator/)
    end
  end

  describe 'typing and forms' do
    it 'passes every key to send_keys' do
      field = element
      driver.script({ id: 'x' }, field)
      page.send_keys({ id: 'x' }, 'a', :tab, timeout: 1)
      expect(field.log).to eq([[:send_keys, 'a', :tab]])
    end

    it 'clears and submits once visible and enabled, returning the element' do
      field = element
      driver.script({ id: 'x' }, element(enabled: false), field)
      expect(page.clear({ id: 'x' }, timeout: 1)).to eq(field)
      expect(page.submit({ id: 'x' }, timeout: 1)).to eq(field)
      expect(field.log).to eq([[:clear], [:submit]])
    end

    it 'selects by text, value and index through Support::Select' do
      dropdown = WaitHelperSpec::FakeSelect.new
      driver.script({ id: 'colour' }, dropdown)
      page.select_by({ id: 'colour' }, :text, 'Blue', timeout: 1)
      page.select_by({ id: 'colour' }, :value, 'green', timeout: 1)
      page.select_by({ id: 'colour' }, :index, 0, timeout: 1)
      expect(dropdown.options.map(&:log)).to eq([[[:click]], [[:click]], [[:click]]])
    end
  end

  describe 'actions' do
    it 'hovers with move_to once the element is stable' do
      menu = element
      driver.script({ id: 'menu' }, menu)
      page.hover({ id: 'menu' }, timeout: 1)
      expect(driver.actions).to eq([[:move_to, menu], [:perform]])
    end

    it 'drags the source onto the target' do
      source = element
      target = element
      driver.script({ id: 'src' }, source).script({ id: 'tgt' }, target)
      expect(page.drag_and_drop({ id: 'src' }, { id: 'tgt' }, timeout: 1)).to eq(source)
      expect(driver.actions).to eq([[:drag_and_drop, source, target], [:perform]])
    end

    it 'scrolls a hidden but present element into view' do
      below = element(displayed: false)
      driver.script({ id: 'below' }, below)
      page.scroll_into_view({ id: 'below' }, timeout: 1)
      expect(driver.actions).to eq([[:scroll_to, below], [:perform]])
    end
  end

  describe 'readers' do
    it 'answer for a present element, hidden included' do
      driver.script({ id: 'x' }, element(displayed: false, text: 'Hello', attributes: { 'href' => '/a' }))
      expect(page.text({ id: 'x' }, timeout: 1)).to eq('Hello')
      expect(page.attribute({ id: 'x' }, 'href', timeout: 1)).to eq('/a')
      expect(page.displayed?({ id: 'x' }, timeout: 1)).to be(false)
      expect(page.enabled?({ id: 'x' }, timeout: 1)).to be(true)
      expect(page.selected?({ id: 'x' }, timeout: 1)).to be(false)
    end

    it 'raise the timeout error when nothing matches' do
      expect { page.text({ id: 'none' }, timeout: 0.2) }.to raise_error(WaitHelper::TimeoutError)
      expect { page.displayed?({ id: 'none' }, timeout: 0.2) }.to raise_error(WaitHelper::TimeoutError)
    end
  end

  describe 'braceless locators' do
    it 'treat keywords as the locator' do
      driver.script({ css: '.x' }, element(tag_name: 'span')).script({ id: 'y' }, element).script({ id: 'z' }, element)
      expect(page.find_element(css: '.x').tag_name).to eq('span')
      page.click(id: 'y')
      expect(page.text(id: 'z')).to eq('hi')
      expect(driver.finds.uniq).to eq([{ css: '.x' }, { id: 'y' }, { id: 'z' }])
    end
  end

  describe 'timeout errors' do
    it 'subclass Selenium TimeoutError, describe the wait and start the backtrace at the caller' do
      driver.script({ id: 'x' }, element(displayed: false))
      expect { page.send_keys({ id: 'x' }, 'a', timeout: 0.3) }.to raise_error(WaitHelper::TimeoutError) { |error|
        expect(error).to be_a(Selenium::WebDriver::Error::TimeoutError)
        expect(error.message)
          .to eq('Waited 0.3s for {id: "x"} to be visible and enabled; last seen: present but not visible')
        expect(error.backtrace.first).to include(File.basename(__FILE__))
        expect(error.backtrace.first).not_to include('wait_helper.rb')
      }
    end
  end

  describe '#eventually' do
    it 'returns the block value after two failing tries' do
      tries = 0
      result = page.eventually(timeout: 1) do
        tries += 1
        expect(tries).to eq(3)
        :done
      end
      expect(result).to eq(:done)
    end

    it 're-raises the last expectation failure with the still-failing prefix' do
      answer = 1
      expect { page.eventually(timeout: 0.3) { expect(answer).to eq(2) } }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError) { |error|
          expect(error.message).to start_with('(still failing after 0.3s)').and(include('expected: 2'))
        }
    end

    it 'raises any other error on the first try' do
      tries = 0
      expect { page.eventually(timeout: 1) { raise "boom #{tries += 1}" } }.to raise_error(RuntimeError, 'boom 1')
    end

    it 'stretches a nested call without timeout: to what is left of its own deadline' do
      allow(WaitHelper).to receive(:default_timeout).and_return(1)
      driver.script({ css: '.x' }, *Array.new(15), element(text: 'y'))
      tries = 0
      started = clock
      page.eventually(timeout: 3) do
        tries += 1
        expect(page.text(css: '.x')).to eq 'y'
      end
      expect([tries, clock - started]).to match([1, be_between(1.3, 2.9)])
    end

    it 'retries a nested timeout: per attempt and fails at its own deadline with the prefix' do
      started = clock
      expect { page.eventually(timeout: 1) { page.text({ css: '.never' }, timeout: 0.2) } }
        .to raise_error(WaitHelper::TimeoutError, /\A\(still failing after 1s\)\nWaited [\d.]+s for \{css: "\.never"\}/)
      expect(clock - started).to be_between(0.9, 1.4)
      expect(driver.finds.size).to be > 5
    end

    it 'caps a nested action at its own deadline' do
      started = clock
      expect { page.eventually(timeout: 0.5) { page.click({ id: 'never' }, timeout: 5) } }
        .to raise_error(WaitHelper::TimeoutError)
      expect(clock - started).to be < 0.8
    end
  end

  describe RaiderElement do
    it 'chains finders, waiting at each level inside the parent' do
      email = element
      form = element.script({ id: 'email' }, nil, email)
      driver.script({ css: '.form' }, nil, form)
      page.find_element(css: '.form').find_element(id: 'email').send_keys('a')
      expect(driver.finds).to eq([{ css: '.form' }] * 2)
      expect(form.finds).to eq([{ id: 'email' }] * 2)
      expect(email.log).to eq([[:send_keys, 'a']])
    end

    it 'returns an Array of wrappers from find_elements' do
      driver.script_many({ css: 'li' }, [element, element])
      expect(page.find_elements(css: 'li')).to all(be_a(described_class))
    end

    it 'delegates unwrapped methods to the raw element and compares by it' do
      raw = element(tag_name: 'a')
      driver.script({ id: 'x' }, raw)
      wrapper = page.find_element(id: 'x')
      other = page.find_element(id: 'x')
      expect([wrapper.tag_name, wrapper.rect, wrapper.respond_to?(:tag_name)]).to eq(['a', [0, 0, 10, 10], true])
      expect(wrapper.native).to be(raw)
      expect([wrapper == raw, wrapper == other, [wrapper, other].uniq.size]).to eq([true, true, 1])
      expect(wrapper).not_to be_a(Selenium::WebDriver::Element)
    end

    it 're-finds a stale wrapper through its scope' do
      first = element
      second = element
      driver.script({ id: 'x' }, first, second)
      wrapper = page.find_element(id: 'x')
      first.go_stale
      wrapper.click(timeout: 1)
      expect([first.log, second.log, wrapper.native]).to eq([[], [[:click]], second])
    end

    it 'keeps its element after a timed-out action' do
      raw = element(tag_name: 'a')
      driver.script({ id: 'x' }, raw, nil)
      wrapper = page.find_element(id: 'x')
      hash = wrapper.hash
      raw.go_hidden
      expect { wrapper.click(timeout: 0.2) }.to raise_error(WaitHelper::TimeoutError)
      expect([wrapper.native, wrapper.tag_name, wrapper == raw, wrapper.hash]).to eq([raw, 'a', true, hash])
    end

    it 'heals a chain when the parent was re-rendered' do
      old_button = element
      new_button = element
      old_form = element.script({ id: 'go' }, old_button)
      new_form = element.script({ id: 'go' }, new_button)
      driver.script({ css: '.form' }, old_form, new_form)
      button = page.find_element(css: '.form').find_element(id: 'go')
      [old_form, old_button].each(&:go_stale)
      button.click(timeout: 1)
      expect(new_button.log).to eq([[:click]])
    end

    it 'raises a stale find_elements member with a re-query hint' do
      item = element
      driver.script_many({ css: 'li' }, [item])
      member = page.find_elements(css: 'li').first
      item.go_stale
      expect { member.click(timeout: 1) }.to raise_error(errors::StaleElementReferenceError, /find_elements again/)
    end

    context 'when a parent that cannot be found again goes stale' do
      let(:raw_row) { element.script({ css: 'td' }, element) }
      let(:hint) { /find_elements again/ }

      def stale_row
        driver.script_many({ css: 'tr' }, [raw_row])
        row = page.find_elements(css: 'tr').first
        raw_row.go_stale
        row
      end

      def at_once
        started = clock
        yield
        expect(clock - started).to be < 0.3
      end

      it 'raises from find_elements at timeout: 0 instead of answering []' do
        row = stale_row
        expect { row.find_elements({ css: '.err' }, timeout: 0) }.to raise_error(errors::StaleElementReferenceError, hint)
      end

      it 'raises from find_elements at once instead of waiting and answering []' do
        row = stale_row
        at_once { expect { row.find_elements(css: 'td', timeout: 2) }.to raise_error(errors::StaleElementReferenceError, hint) }
      end

      it 'raises from find_element at once with the hint' do
        row = stale_row
        at_once { expect { row.find_element(css: 'td', timeout: 2) }.to raise_error(errors::StaleElementReferenceError, hint) }
      end

      it 'raises for a parent passed in as an element, suggesting a locator' do
        parent = page.find_element(raw_row)
        raw_row.go_stale
        at_once do
          expect { parent.find_element(css: 'td', timeout: 2) }
            .to raise_error(errors::StaleElementReferenceError, /pass .*locator/)
        end
      end

      it 'raises at once for a stale ancestor further up the chain' do
        leaf = element
        middle = element.script({ css: 'td' }, leaf)
        raw_row.script({ css: '.cell' }, middle)
        driver.script_many({ css: 'tr' }, [raw_row])
        button = page.find_elements(css: 'tr').first.find_element(css: '.cell').find_element(css: 'td')
        [raw_row, middle, leaf].each(&:go_stale)
        at_once { expect { button.click(timeout: 2) }.to raise_error(errors::StaleElementReferenceError, hint) }
      end

      it 'still re-finds a stale child inside a live parent' do
        old_button = element
        new_button = element
        raw_row.script({ css: 'button' }, old_button, new_button)
        driver.script_many({ css: 'tr' }, [raw_row])
        button = page.find_elements(css: 'tr').first.find_element(css: 'button')
        old_button.go_stale
        button.click(timeout: 1)
        expect(new_button.log).to eq([[:click]])
      end
    end

    it 'passes both raw elements to drag_and_drop' do
      source = element
      target = element
      driver.script({ id: 'src' }, source).script({ id: 'tgt' }, target)
      page.find_element(id: 'src').drag_and_drop(page.find_element(id: 'tgt'))
      step = driver.actions.first
      expect([step[1].equal?(source), step[2].equal?(target)]).to eq([true, true])
    end

    it 'adds exactly the planned public methods' do
      expect(described_class.public_instance_methods(false).sort)
        .to eq(%i[== attribute clear click displayed? drag_and_drop enabled? eql? find_element find_elements hash
                  hover native scroll_into_view select_by selected? send_keys submit text])
    end
  end

  describe 'the choke point' do
    let(:actions) { [] }

    before do
      dropdown = WaitHelperSpec::FakeSelect.new
      dropdown.script({ css: 'y' }, element).script_many({ css: 'y' }, [element])
      driver.script({ id: 'x' }, dropdown)
      allow_any_instance_of(WaitHelper::Waiter).to receive(:perform_action).and_wrap_original do |original, *args, **options, &block|
        actions << args.first
        original.call(*args, **options, &block)
      end
    end

    def calls(locator)
      { find_element: [locator], find_elements: [locator], click: [locator], clear: [locator], submit: [locator],
        hover: [locator], scroll_into_view: [locator], text: [locator], displayed?: [locator],
        enabled?: [locator], selected?: [locator], send_keys: [locator, 'a'], select_by: [locator, :text, 'Blue'],
        attribute: [locator, 'href'], drag_and_drop: [locator, locator] }
    end

    it 'is called once per mixin method, with the method name' do
      calls({ id: 'x' }).each do |name, args|
        actions.clear
        page.public_send(name, *args, timeout: 1)
        expect(actions).to eq([name])
      end
    end

    it 'is called once per wrapper method, with the method name' do
      wrapper = page.find_element(id: 'x')
      calls({ css: 'y' }).each do |name, args|
        args = args.drop(1) unless %i[find_element find_elements drag_and_drop].include?(name)
        args = [wrapper] if name == :drag_and_drop
        actions.clear
        wrapper.public_send(name, *args, timeout: 1)
        expect(actions).to eq([name])
      end
    end
  end

  describe 'footprint' do
    it 'adds exactly the public API, with no private methods and nothing named wait' do
      expect(WaitHelper.public_instance_methods(false).sort)
        .to eq(%i[attribute clear click displayed? drag_and_drop enabled? eventually find_element find_elements hover
                  scroll_into_view select_by selected? send_keys submit text])
      expect(WaitHelper.private_instance_methods(false)).to be_empty
      expect(page.respond_to?(:wait, true)).to be(false)
    end
  end

  describe '.observer' do
    # Records every hook call; tokens are the call's index.
    let(:observer) do
      Class.new do
        attr_reader :calls

        def initialize = @calls = []

        %i[action_started group_started].each do |hook|
          define_method(hook) do |**details|
            @calls << [hook, details]
            @calls.size - 1
          end
        end

        %i[action_finished group_retried group_finished].each do |hook|
          define_method(hook) do |token, **details|
            @calls << [hook, token, details]
          end
        end
      end.new
    end

    around do |example|
      WaitHelper.observer = observer
      example.run
    ensure
      WaitHelper.observer = nil
    end

    def started = observer.calls.select { |call| call.first == :action_started }.map(&:last)
    def finished = observer.calls.select { |call| call.first == :action_finished }.map(&:last)

    it 'reports a click with its locator, source line, waited time and the ready element' do
      button = element
      driver.script({ id: 'go' }, nil, button)
      line = __LINE__ + 1
      page.click({ id: 'go' }, timeout: 1)

      expect(observer.calls.first(2).map(&:first)).to eq(%i[action_started action_finished])
      expect(started.first).to include(action: :click, locator: { strategy: 'id', selector: 'go' }, within: [], label: nil,
                                       source: { file: Pathname(__FILE__).relative_path_from(Dir.pwd).to_s, line: line })
      expect(observer.calls[1][1]).to eq(0)
      expect(finished.first).to include(status: :passed, retries: 2, error: nil, element: button)
      expect(finished.first[:waited_ms]).to be_between(50, 500)
    end

    it 'reports a chained find with within, outermost first' do
      driver.script({ css: '.form' }, element.script({ tag_name: 'td' }, element.script({ id: 'email' }, element)))
      page.find_element(css: '.form').find_element(tag_name: 'td').find_element(id: 'email')

      expect(started.last).to include(action: :find_element, locator: { strategy: 'id', selector: 'email' },
                                      within: [{ strategy: 'css', selector: '.form' }, { strategy: 'tag_name', selector: 'td' }])
    end

    it 'reports a timed-out action as failed with its error, then re-raises' do
      driver.script({ id: 'gone' }, nil)
      expect { page.click({ id: 'gone' }, timeout: 0.3) }.to raise_error(WaitHelper::TimeoutError)

      expect(finished.first).to include(status: :failed, element: nil)
      expect(finished.first[:error]).to be_a(WaitHelper::TimeoutError)
      expect(finished.first[:retries]).to be >= 2
    end

    it 'reports eventually as a group with the retries it took' do
      tries = 0
      page.eventually(timeout: 2) { expect(tries += 1).to eq(3) }

      group = observer.calls.find { |call| call.first == :group_started }.last
      expect(group).to include(action: :eventually)
      expect(group[:source]).to include(line: be_a(Integer))
      expect(observer.calls.last).to match([:group_finished, 0, { status: :passed, retries: 2, error: nil }])
    end

    it 'reports group_retried with the group token and the earlier error before each new pass of eventually' do
      tries = 0
      page.eventually(timeout: 2) { expect(tries += 1).to eq(3) }

      retried = observer.calls.select { |call| call.first == :group_retried }
      expect(retried.map { |call| call[1] }).to eq([0, 0])
      expect(retried.map { |call| call.last[:error] }).to all(be_a(RSpec::Expectations::ExpectationNotMetError))
      expect(observer.calls.map(&:first)).to eq(%i[group_started group_retried group_retried group_finished])
    end

    it 'reports a failing eventually as failed with its error' do
      tries = 0
      expect { page.eventually(timeout: 0.2) { expect(tries += 1).to eq(0) } }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      expect(observer.calls.last.last).to include(status: :failed, error: be_a(RSpec::Expectations::ExpectationNotMetError))
    end

    it 'normalises class to class_name and link to link_text' do
      aliases = { css_selector: 'css', class: 'class_name', link: 'link_text', partial_link: 'partial_link_text', name: 'name' }
      aliases.each_key do |strategy|
        driver.script({ strategy => 'x' }, element)
        page.displayed?({ strategy => 'x' }, timeout: 0)
      end

      expect(started.map { |event| event[:locator][:strategy] }).to eq(aliases.values)
    end

    it 'labels an action by the nearest page_objects method' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'page_objects'))
        path = File.join(dir, 'page_objects', 'login.rb')
        File.write(path, "def login_button(page) = page.click({ id: 'go' }, timeout: 1)\n")
        load path
        driver.script({ id: 'go' }, element)
        login_button(page)
      end

      expect(started.first).to include(label: 'login_button')
      expect(started.first[:source][:file]).to end_with('page_objects/login.rb')
    end

    it 'drops the observer, warns once, and still clicks when working out the source raises' do
      button = element
      driver.script({ id: 'go' }, button)
      allow(Dir).to receive(:pwd).and_raise(Errno::ENOENT)

      expect { 2.times { page.click({ id: 'go' }, timeout: 1) } }.to output(/\A\[trace\] observer stopped: Errno::ENOENT.*\n\z/).to_stderr
      expect(button.log).to eq([%i[click]] * 2)
      expect(WaitHelper.observer).to be_nil
    end

    it 'drops an observer that raises, warns once, and still clicks' do
      allow(observer).to receive(:action_started).and_raise('boom')
      button = element
      driver.script({ id: 'go' }, button)

      expect { 2.times { page.click({ id: 'go' }, timeout: 1) } }.to output(/\A\[trace\] observer stopped: RuntimeError: boom\n\z/).to_stderr
      expect(button.log).to eq([%i[click]] * 2)
      expect(WaitHelper.observer).to be_nil
    end
  end

  describe '.default_timeout' do
    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { example.run }
      ensure
        WaitHelper.instance_variable_set(:@default_timeout, nil)
      end
    end

    it 'is 10 without config/config.yml' do
      WaitHelper.instance_variable_set(:@default_timeout, nil)
      expect(WaitHelper.default_timeout).to eq(10)
    end

    it 'reads timeout from config/config.yml' do
      WaitHelper.instance_variable_set(:@default_timeout, nil)
      Dir.mkdir('config')
      File.write('config/config.yml', YAML.dump('timeout' => 3))
      expect(WaitHelper.default_timeout).to eq(3)
    end
  end
end
