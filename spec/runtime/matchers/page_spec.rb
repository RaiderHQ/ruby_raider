# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime/rspec'

RSpec.describe 'Raider page matchers' do
  include Raider::Matchers

  # A driver whose title and url change from poll to poll; the last answer repeats.
  let(:driver_class) do
    Class.new do
      def initialize(titles, urls)
        @titles = titles
        @urls = urls
      end

      def title
        @titles.size > 1 ? @titles.shift : @titles.first
      end

      def current_url
        @urls.size > 1 ? @urls.shift : @urls.first
      end
    end
  end

  after { Raider.reset }

  describe 'have_count' do
    it 'passes at once on an Array of the right size' do
      expect(have_count(2).matches?([1, 2])).to be(true)
    end

    it 'fails an Array without waiting' do
      matcher = have_count(2, wait: 10)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(matcher.matches?([1])).to be(false)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.05
      expect(matcher.failure_message).to eq('expected the array to have count 2, last seen 1 after 0s')
    end

    it 'passes on the first poll for a block whose find_elements is always empty' do
      driver = Raider::Spec.driver(Raider::Spec::FakeBridge.new)
      calls = 0
      Raider.timeout = 5
      expect { (calls += 1) && driver.find_elements(css: '.row') }.to have_count(0)
      expect(calls).to eq(1)
    end

    it 'keeps calling a block until the count arrives' do
      calls = 0
      expect { (calls += 1) > 2 ? [1, 2, 3] : [] }.to have_count(3)
    end

    it 'words a block failure with the last count' do
      matcher = have_count(3, wait: 0.2)
      expect(matcher.matches?(-> { [1, 2] })).to be(false)
      expect(matcher.failure_message).to match(/\A#{Regexp.escape('expected the block to have count 3, last seen 2 after ')}0\.\d+s\z/)
    end

    it 'waits for the count to leave when negated' do
      sizes = [[1, 2, 3], [1, 2, 3], [1]]
      expect(have_count(3, wait: 1).does_not_match?(-> { sizes.size > 1 ? sizes.shift : sizes.first })).to be(true)
    end
  end

  describe 'have_title' do
    it 'passes once the title changes' do
      driver = driver_class.new(%w[Loading Account], [''])
      expect(have_title('Account', wait: 1).matches?(driver)).to be(true)
    end

    it 'accepts a Regexp' do
      expect(driver_class.new(['My Account'], [''])).to have_title(/Account\z/)
    end

    it 'fails with the last title' do
      matcher = have_title('Account', wait: 0.2)
      expect(matcher.matches?(driver_class.new(['Home'], ['']))).to be(false)
      expect(matcher.failure_message).to match(/\A#{Regexp.escape('expected the page to have title "Account", last seen "Home" after ')}0\.\d+s\z/)
    end
  end

  describe 'have_url' do
    let(:driver) { driver_class.new([''], ['https://x/account']) }

    it 'matches a Regexp' do
      expect(driver).to have_url(%r{/account$})
    end

    it 'matches a whole String' do
      expect(driver).to have_url('https://x/account')
    end

    it 'does not match a fragment of the url' do
      matcher = have_url('account', wait: 0.2)
      expect(matcher.matches?(driver)).to be(false)
      expect(matcher.failure_message)
        .to match(/\A#{Regexp.escape('expected the page to have url "account", last seen "https://x/account" after ')}0\.\d+s\z/)
    end
  end
end
