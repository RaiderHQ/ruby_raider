# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime/rspec'

RSpec.describe 'Raider::Matchers::Base' do
  after { Raider.reset }

  let(:matcher_class) do
    Class.new(Raider::Matchers::Base) do
      def verb = 'have value'
      def read(subject) = subject.value
      def pass?(value) = value == expected
    end
  end

  let(:subject_class) do
    Class.new do
      attr_reader :reads

      def initialize(*values, error: nil)
        @values = values
        @error = error
        @reads = 0
      end

      def value
        @reads += 1
        raise @error, 'gone' if @error

        @values[[@reads, @values.size].min - 1]
      end

      def tag_name = raise(Selenium::WebDriver::Error::WebDriverError, 'no tag')
    end
  end

  it 'passes once the value changes to the expected one' do
    element = subject_class.new('a', 'a', 'b')
    expect(matcher_class.new('b', wait: 1).matches?(element)).to be(true)
    expect(element.reads).to be >= 3
  end

  it 'retries the negated form until the value changes away' do
    element = subject_class.new('b', 'b', 'a')
    expect(matcher_class.new('b', wait: 1).does_not_match?(element)).to be(true)
    expect(element.reads).to be >= 3
  end

  it 'reports the last value seen after the wait' do
    matcher = matcher_class.new('b', wait: 0.2)
    expect(matcher.matches?(subject_class.new('a'))).to be(false)
    expect(matcher.failure_message).to eq('expected <element> to have value "b", last seen "a" after 0.2s')
  end

  it 'words the negated failure' do
    matcher = matcher_class.new('a', wait: 0.2)
    expect(matcher.does_not_match?(subject_class.new('a'))).to be(false)
    expect(matcher.failure_message_when_negated)
      .to eq('expected <element> not to have value "a", last seen "a" after 0.2s')
  end

  it 'uses the configured timeout when wait is nil' do
    Raider.timeout = 0.2
    matcher = matcher_class.new('b')
    matcher.matches?(subject_class.new('a'))
    expect(matcher.failure_message).to end_with('after 0.2s')
  end

  it 'calls a Proc actual on every poll and describes it as the block' do
    calls = 0
    matcher = matcher_class.new('b', wait: 0.3)
    result = matcher.matches?(proc { subject_class.new("v#{calls += 1}") })
    expect(result).to be(false)
    expect(calls).to be >= 2
    expect(matcher.failure_message).to start_with('expected the block to have value "b", last seen "v')
  end

  it 'propagates an error raised by a Proc actual' do
    expect { matcher_class.new('b', wait: 1).matches?(proc { raise 'boom' }) }.to raise_error(RuntimeError, 'boom')
  end

  it 'reports not found when the element never appears' do
    element = subject_class.new(error: Selenium::WebDriver::Error::NoSuchElementError)
    matcher = matcher_class.new('b', wait: 0.2)
    expect(matcher.matches?(element)).to be(false)
    expect(matcher.failure_message).to include('last seen: not found')
  end

  it 'counts absence as a pass when the matcher allows it' do
    absent = Class.new(matcher_class) { def absent_passes? = true }
    element = subject_class.new(error: Selenium::WebDriver::Error::StaleElementReferenceError)
    expect(absent.new('x', wait: 0.2).matches?(element)).to be(true)
    expect(absent.new('x', wait: 0.2).does_not_match?(element)).to be(false)
  end

  it 'supports block expectations and describes itself' do
    matcher = matcher_class.new('b')
    expect(matcher.supports_block_expectations?).to be(true)
    expect(matcher.description).to eq('have value "b"')
  end

  describe '#read_with_zero_wait' do
    let(:reader) { matcher_class.new('x') }

    it 'passes timeout: 0 when the method accepts it' do
      target = Class.new { def text(timeout: 5) = timeout }.new
      expect(reader.read_with_zero_wait(target, :text)).to eq(0)
    end

    it 'omits it otherwise' do
      target = Class.new { def text = 'plain' }.new
      expect(reader.read_with_zero_wait(target, :text)).to eq('plain')
    end
  end
end
