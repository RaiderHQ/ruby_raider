# frozen_string_literal: true

require 'erb'
require 'tmpdir'
require_relative '../../lib/generators/helper_generator'
require_relative '../../lib/ruby_raider/runtime'

# Stands in for the Appium driver: only the calls the gestures make.
class GestureDriver
  Rect = Struct.new(:x, :y, :width, :height)
  Element = Struct.new(:id)

  attr_reader :appium_device

  def initialize(device)
    @appium_device = device
  end

  def execute_script(*); end

  def find_element(*); end

  def window_rect
    Rect.new(0, 10, 400, 800)
  end
end

class GesturePage
  attr_reader :driver

  def initialize(driver)
    @driver = driver
  end

  def self.rendered
    generator = HelpersGenerator.new(%w[ios rspec proj])
    template = File.expand_path('../../lib/generators/templates/helpers/gesture_helper.tt', __dir__)
    ERB.new(File.read(template), trim_mode: '-').result(generator.instance_eval { binding })
  end
end

Dir.mktmpdir do |dir|
  path = File.join(dir, 'gesture_helper.rb')
  File.write(path, GesturePage.rendered)
  load path
end
GesturePage.include(GestureHelper)

describe 'gesture_helper template' do
  let(:element) { GestureDriver::Element.new('el-1') }
  let(:driver) { GestureDriver.new(:android) }
  let(:page) { GesturePage.new(driver) }

  context 'on iOS' do
    let(:driver) { GestureDriver.new(:ios) }

    it 'swipes the screen with mobile: swipe' do
      expect(driver).to receive(:execute_script).with('mobile: swipe', { direction: 'left' })
      page.swipe('left')
    end

    it 'scrolls an element with mobile: scroll and its id' do
      expect(driver).to receive(:execute_script).with('mobile: scroll', { direction: 'down', element: 'el-1' })
      page.scroll(:down, element)
    end
  end

  context 'on Android' do
    let(:driver) { GestureDriver.new(:android) }

    it 'swipes the screen with mobile: swipeGesture over the window rect' do
      expect(driver).to receive(:execute_script)
        .with('mobile: swipeGesture', { left: 0, top: 10, width: 400, height: 800, direction: 'up', percent: 0.75 })
      page.swipe('up')
    end

    it 'scrolls an element with mobile: scrollGesture and its element id' do
      expect(driver).to receive(:execute_script)
        .with('mobile: scrollGesture', { elementId: 'el-1', direction: 'down', percent: 0.75 })
      page.scroll('down', element)
    end
  end

  it 'rejects a direction other than up, down, left or right' do
    driver = GestureDriver.new(:ios)
    page = GesturePage.new(driver)
    expect { page.swipe('diagonal') }.to raise_error(ArgumentError, /direction must be up, down, left or right/)
  end

  describe '#scroll_to' do
    let(:locator) { { accessibility_id: 'footer' } }

    let(:driver) { GestureDriver.new(:android) }

    it 'returns the element without scrolling when it is already there' do
      allow(driver).to receive(:find_element).with(locator).and_return(element)
      expect(driver).not_to receive(:execute_script)
      expect(page.scroll_to(locator)).to eq(element)
    end

    it 'scrolls between tries until the element appears' do
      attempts = 0
      allow(driver).to receive(:find_element).with(locator) do
        attempts += 1
        raise Selenium::WebDriver::Error::NoSuchElementError, 'gone' if attempts < 3

        element
      end
      expect(driver).to receive(:execute_script).twice
      expect(page.scroll_to(locator, direction: 'up')).to eq(element)
    end

    it 'gives up after max_scrolls and names the locator' do
      allow(driver).to receive(:find_element).and_raise(Selenium::WebDriver::Error::NoSuchElementError, 'gone')
      expect(driver).to receive(:execute_script).exactly(3).times
      expect { page.scroll_to(locator, max_scrolls: 3) }
        .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /accessibility_id.*footer.*after 3 scrolls/)
    end
  end
end
