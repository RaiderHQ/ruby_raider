# frozen_string_literal: true

require_relative 'wait_helper_support'

# The mobile render loads into App, so its WaitHelper and RaiderElement never meet the web
# render's top-level ones when both spec files run in one process.
module WaitHelperMobileSpec
  module App; end
  WaitHelperSpec.load_templates(mobile: true, into: App)

  class Page
    include App::WaitHelper

    attr_reader :driver

    def initialize(driver)
      @driver = driver
    end
  end

  RSpec.describe 'WaitHelper on mobile' do
    let(:driver) { WaitHelperSpec::FakeDriver.new(device: :ios) }
    let(:android) { WaitHelperSpec::FakeDriver.new(device: :android) }
    let(:page) { Page.new(driver) }
    let(:per_os) { { ios: { accessibility_id: 'ios-card' }, android: { accessibility_id: 'android-card' } } }

    def element(**state) = WaitHelperSpec::FakeElement.new(**state)
    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    def screen_area = { left: 0, top: 20, width: 390, height: 800 }

    describe '#tap and #click' do
      it 'click once the element is visible, enabled and stable' do
        %i[tap click].each do |name|
          target = element(rects: [[0, 0, 10, 10], [5, 5, 10, 10], [5, 5, 10, 10]])
          driver.script({ accessibility_id: name.to_s }, nil, element(displayed: false), element(enabled: false), target)
          expect(page.public_send(name, { accessibility_id: name.to_s }, timeout: 2)).to eq(target)
          expect(target.log).to eq([[:click]])
        end
      end
    end

    describe 'tap with a block' do
      it 'is Object#tap on a RaiderElement: yields and returns the wrapper without clicking' do
        card = element
        driver.script({ accessibility_id: 'card' }, card)
        wrapper = page.find_element(accessibility_id: 'card')
        seen = nil
        expect(wrapper.tap { |yielded| seen = yielded }).to be(wrapper)
        expect([seen, card.log]).to eq([wrapper, []])
      end

      it 'is Object#tap on the mixin: yields self without looking anything up' do
        seen = nil
        expect(page.tap { |yielded| seen = yielded }).to be(page)
        expect(page.tap(&:driver)).to be(page)
        expect([seen, driver.finds, driver.scripts]).to eq([page, [], []])
      end

      it 'still clicks without a block' do
        card = element
        driver.script({ id: 'x' }, card)
        page.tap({ id: 'x' }, timeout: 1)
        page.tap(id: 'x')
        page.find_element(id: 'x').tap
        expect(card.log).to eq([[:click]] * 3)
      end
    end

    describe '#swipe' do
      it 'uses mobile: swipe on iOS' do
        card = element
        driver.script({ accessibility_id: 'card' }, card)
        expect(page.swipe('left', { accessibility_id: 'card' }, timeout: 1)).to eq(card)
        expect(driver.scripts).to eq([['mobile: swipe', { direction: 'left', element: card.id }]])
      end

      it 'uses mobile: swipeGesture on Android' do
        card = element
        android.script({ accessibility_id: 'card' }, card)
        Page.new(android).swipe('left', { accessibility_id: 'card' }, timeout: 1)
        expect(android.scripts)
          .to eq([['mobile: swipeGesture', { elementId: card.id, direction: 'left', percent: 0.75 }]])
      end

      it 'waits for the element to be visible first' do
        card = element
        driver.script({ accessibility_id: 'card' }, nil, element(displayed: false), card)
        page.swipe('up', { accessibility_id: 'card' }, timeout: 1)
        expect([driver.finds.size, driver.scripts.size]).to eq([3, 1])
      end

      it 'swipes the whole screen without a locator' do
        expect(page.swipe('up')).to be_nil
        Page.new(android).swipe('up')
        expect(driver.scripts).to eq([['mobile: swipe', { direction: 'up' }]])
        expect(android.scripts).to eq([['mobile: swipeGesture', { **screen_area, direction: 'up', percent: 0.75 }]])
      end

      it 'rejects a direction other than up, down, left or right' do
        expect { page.swipe('sideways') }.to raise_error(ArgumentError, /up, down, left or right/)
        expect(driver.scripts).to be_empty
      end
    end

    describe '#scroll' do
      it 'scrolls the screen without a locator' do
        page.scroll('down')
        Page.new(android).scroll('down')
        expect(driver.scripts).to eq([['mobile: scroll', { direction: 'down' }]])
        expect(android.scripts).to eq([['mobile: scrollGesture', { **screen_area, direction: 'down', percent: 0.75 }]])
      end

      it 'scrolls a container' do
        list = element
        android.script({ id: 'list' }, list)
        Page.new(android).scroll('up', { id: 'list' }, timeout: 1)
        expect(android.scripts).to eq([['mobile: scrollGesture', { elementId: list.id, direction: 'up', percent: 0.75 }]])
      end
    end

    describe 'an unknown device' do
      it 'raises NotImplementedError naming it, before waiting' do
        windows = WaitHelperSpec::FakeDriver.new(device: :windows)
        started = clock
        expect { Page.new(windows).swipe('left', { id: 'never' }, timeout: 2) }
          .to raise_error(NotImplementedError, /windows/)
        expect { Page.new(windows).scroll('down') }.to raise_error(NotImplementedError, /windows/)
        expect(clock - started).to be < 0.5
      end
    end

    describe '#scroll_to' do
      it 'returns a RaiderElement once the element turns visible after 2 scrolls' do
        footer = element
        driver.script({ accessibility_id: 'footer' }, nil, element(displayed: false), footer)
        found = page.scroll_to({ accessibility_id: 'footer' }, timeout: 2)
        expect(found).to be_a(App::RaiderElement).and eq(footer)
        expect(driver.scripts).to eq([['mobile: scroll', { direction: 'down' }]] * 2)
      end

      it 'scrolls in the given direction' do
        driver.script({ accessibility_id: 'header' }, nil, element)
        page.scroll_to({ accessibility_id: 'header' }, direction: 'up', timeout: 2)
        expect(driver.scripts).to eq([['mobile: scroll', { direction: 'up' }]])
      end

      it 'stops after max_scrolls scrolls and says so' do
        started = clock
        expect { page.scroll_to({ accessibility_id: 'footer' }, max_scrolls: 3, timeout: 5) }
          .to raise_error(App::WaitHelper::TimeoutError) { |error|
            expect(error.message).to include('to be visible').and include('after 3 scrolls')
          }
        expect(driver.scripts.size).to eq(3)
        expect(driver.finds.size).to eq(4)
        expect(clock - started).to be < 2
      end

      it 'also stops at the timeout, naming the scrolls so far' do
        expect { page.scroll_to({ accessibility_id: 'footer' }, timeout: 0) }
          .to raise_error(App::WaitHelper::TimeoutError, /after 0 scrolls/)
        expect(driver.scripts).to be_empty
      end
    end

    describe 'per-OS locators' do
      it 'resolve on tap and swipe' do
        card = element
        android.script({ accessibility_id: 'android-card' }, card)
        mobile = Page.new(android)
        mobile.tap(per_os, timeout: 1)
        mobile.swipe('right', per_os, timeout: 1)
        expect(android.finds.uniq).to eq([{ accessibility_id: 'android-card' }])
        expect([card.log, android.scripts.size]).to eq([[[:click]], 1])
      end

      it 'resolve on a nested find_element' do
        row = element
        list = element.script({ accessibility_id: 'ios-row' }, row)
        driver.script({ accessibility_id: 'ios-card' }, list)
        found = page.find_element(per_os).find_element({ ios: { accessibility_id: 'ios-row' }, android: { id: 'row' } })
        expect(found).to eq(row)
      end
    end

    describe 'RaiderElement' do
      it 'has the mobile set without the locator' do
        card = element
        driver.script({ accessibility_id: 'card' }, card)
        wrapper = page.find_element(accessibility_id: 'card')
        expect(wrapper.tap.swipe('left').scroll('down').scroll_to).to be(wrapper)
        expect(card.log).to eq([[:click]])
        expect(driver.scripts).to eq([['mobile: swipe', { direction: 'left', element: card.id }],
                                      ['mobile: scroll', { direction: 'down', element: card.id }]])
      end

      it 'adds exactly the planned public methods' do
        expect(App::RaiderElement.public_instance_methods(false).sort)
          .to eq(%i[== attribute clear click displayed? enabled? eql? find_element find_elements hash native scroll
                    scroll_to selected? send_keys swipe tap text])
      end
    end

    describe 'the choke point' do
      let(:actions) { [] }

      before do
        driver.script({ id: 'x' }, element.script({ css: 'y' }, element).script_many({ css: 'y' }, [element]))
        allow_any_instance_of(App::WaitHelper::Waiter).to receive(:perform_action).and_wrap_original do |original, *args, **options, &block|
          actions << args.first
          original.call(*args, **options, &block)
        end
      end

      def calls(locator)
        { find_element: [locator], find_elements: [locator], click: [locator], tap: [locator], clear: [locator],
          text: [locator], displayed?: [locator], enabled?: [locator], selected?: [locator],
          send_keys: [locator, 'a'], attribute: [locator, 'name'], swipe: ['left', locator],
          scroll: ['down', locator], scroll_to: [locator] }
      end

      it 'is called once per mixin method, with the method name' do
        calls({ id: 'x' }).each do |name, args|
          actions.clear
          page.public_send(name, *args, timeout: 1)
          expect(actions).to eq([name])
        end
      end

      it 'is called once for a whole-screen gesture' do
        %i[swipe scroll].each do |name|
          actions.clear
          page.public_send(name, 'up')
          expect(actions).to eq([name])
        end
      end

      it 'is called once per wrapper method, with the method name' do
        wrapper = page.find_element(id: 'x')
        calls({ css: 'y' }).each do |name, args|
          args = args.reject { |arg| arg.is_a?(Hash) } unless %i[find_element find_elements].include?(name)
          actions.clear
          wrapper.public_send(name, *args, timeout: 1)
          expect(actions).to eq([name])
        end
      end
    end

    describe 'footprint' do
      it 'adds exactly the mobile API, with no private methods and nothing named wait' do
        expect(App::WaitHelper.public_instance_methods(false).sort)
          .to eq(%i[attribute clear click displayed? enabled? eventually find_element find_elements scroll scroll_to
                    selected? send_keys swipe tap text])
        expect(App::WaitHelper.private_instance_methods(false)).to be_empty
        expect(page.respond_to?(:wait, true)).to be(false)
      end
    end

    describe '#eventually' do
      it 'retries the block as on web' do
        tries = 0
        expect(page.eventually(timeout: 1) { expect(tries += 1).to eq(2) }).to be(true)
      end

      it 'retries a nested timeout: until its own deadline, as on web' do
        started = clock
        expect { page.eventually(timeout: 0.6) { page.text({ accessibility_id: 'never' }, timeout: 0.2) } }
          .to raise_error(App::WaitHelper::TimeoutError, /\A\(still failing after 0.6s\)/)
        expect(clock - started).to be_between(0.5, 1.0)
      end

      it 'raises at once for a stale find_elements member used as a parent' do
        row = element.script({ accessibility_id: 'cell' }, element)
        driver.script_many({ accessibility_id: 'row' }, [row])
        member = page.find_elements(accessibility_id: 'row').first
        row.go_stale
        expect { member.find_element(accessibility_id: 'cell', timeout: 2) }
          .to raise_error(Selenium::WebDriver::Error::StaleElementReferenceError, /find_elements again/)
      end
    end
  end
end
