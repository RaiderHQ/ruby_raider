# frozen_string_literal: true

require 'rspec'
require_relative '../../../lib/ruby_raider/runtime/rspec'

RSpec.describe 'Raider block expectations with value matchers' do
  include Raider::Matchers

  before { Raider.timeout = 0.3 }

  after { Raider.reset }

  let(:counter) do
    Class.new do
      attr_reader :calls

      def initialize = @calls = 0
      def next_value = @calls += 1
    end.new
  end

  it 'retries a value matcher until the block value matches' do
    expect { counter.next_value }.to eq(3)
    expect(counter.calls).to eq(3)
  end

  it 'fails with the waited time and rspec own message' do
    expect { expect { 1 }.to eq(2) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /\(waited 0\.3\d?s\) \nexpected: 2\n     got: 1/)
  end

  it 'fails a negated matcher with the waited time' do
    expect { expect { 'x' }.not_to eq('x') }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /\(waited 0\.3\d?s\) \nexpected: value != "x"\n     got: "x"/)
  end

  it 'retries not_to include until the value stops including it' do
    values = [%w[x y], %w[x], %w[y]]
    expect { values.size > 1 ? values.shift : values.first }.not_to include('x')
  end

  it 'retries to_not as well' do
    values = [1, 1, 2]
    expect { values.size > 1 ? values.shift : values.first }.to_not eq(1) # rubocop:disable RSpec/NotToNot
  end

  it 'retries match, be_empty and be > 3' do
    n = 0
    expect { (n += 1) > 1 ? 'abc' : 'x' }.to match(/abc/)
    m = 0
    expect { (m += 1) > 1 ? [] : [1] }.to be_empty
    k = 0
    expect { k += 1 }.to be > 3
  end

  it 'retries through lookup errors' do
    calls = 0
    result = proc do
      raise Selenium::WebDriver::Error::NoSuchElementError, 'gone' if (calls += 1) <= 2

      'ok'
    end
    expect(&result).to eq('ok')
    expect(calls).to eq(3)
  end

  it 'retries AmbiguousMatch and stale elements' do
    calls = 0
    expect do
      calls += 1
      raise Raider::AmbiguousMatch.new('d', []) if calls == 1
      raise Selenium::WebDriver::Error::StaleElementReferenceError, 'stale' if calls == 2

      7
    end.to eq(7)
  end

  it 're-raises the last lookup error when no value was ever read' do
    expect { expect { raise Selenium::WebDriver::Error::NoSuchElementError, 'never' }.to eq(1) }
      .to raise_error(Selenium::WebDriver::Error::NoSuchElementError, /never/)
  end

  it 'makes finds inside the block a single attempt' do
    seen = nil
    expect { seen = Raider::Wait.immediate? }.to be(true)
    expect(seen).to be(true)
  end

  it 'evaluates raise_error once' do
    calls = 0
    expect { (calls += 1) && raise(ArgumentError) }.to raise_error(ArgumentError)
    expect(calls).to eq(1)
  end

  it 'evaluates change once' do
    list = []
    calls = 0
    expect { list << (calls += 1) }.to change { list.size }.by(1)
    expect(calls).to eq(1)
  end

  it 'evaluates output once' do
    calls = 0
    expect { [calls += 1, print('a')] }.to output('a').to_stdout
    expect(calls).to eq(1)
  end

  it 'keeps a Raider matcher on a block as it was' do
    list = [1]
    expect { list }.to have_count(1)
  end
end
