# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime/wait'

RSpec.describe 'Raider::Wait' do
  after { Raider.reset }

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  describe '.until' do
    it 'returns the block value' do
      expect(Raider::Wait.until(timeout: 1) { :ready }).to eq(:ready)
    end

    it 'polls until the block succeeds' do
      calls = 0
      result = Raider::Wait.until(timeout: 1, interval: 0) { (calls += 1) >= 3 && calls }
      expect([result, calls]).to eq([3, 3])
    end

    it 'raises with the thrown reason on the deadline' do
      expect { Raider::Wait.until(timeout: 0.05, interval: 0) { throw :not_ready, 'still moving' } }
        .to raise_error(Raider::TimeoutError, 'still moving')
    end

    it 'raises a default reason when nothing was thrown' do
      expect { Raider::Wait.until(timeout: 0.05, interval: 0) { false } }
        .to raise_error(Raider::TimeoutError, 'condition not met')
    end

    it 'uses Raider.timeout when none is given' do
      Raider.timeout = 0.05
      expect { Raider::Wait.until(interval: 0) { nil } }.to raise_error(Raider::TimeoutError)
    end

    it 'restores the deadline afterwards' do
      Raider::Wait.until(timeout: 1) { Raider::Wait.deadline }
      expect(Raider::Wait.deadline).to be_nil
    end
  end

  describe '.eventually' do
    it 'never waits past an enclosing deadline' do
      started = clock
      expect { Raider.eventually(timeout: 0.3) { Raider::Wait.until(timeout: 5, interval: 0) { false } } }
        .to raise_error(Raider::TimeoutError)
      expect(clock - started).to be < 0.5
    end

    it 'gives a nested call without timeout what is left' do
      seen = nil
      Raider.eventually(timeout: 2) { seen = Raider::Wait.until { Raider::Wait.deadline } }
      expect(seen).to be <= clock + 2
    end

    it 'retries AmbiguousMatch then passes' do
      calls = 0
      result = Raider.eventually(timeout: 1) do
        raise Raider::AmbiguousMatch.new('desc', []) if (calls += 1) == 1

        :done
      end
      expect([result, calls]).to eq([:done, 2])
    end

    it 'prefixes the last error with the time waited' do
      expect { Raider.eventually(timeout: 0.1) { raise Raider::TimeoutError, 'covered' } }
        .to raise_error(Raider::TimeoutError, /\A\(still failing after 0\.1s\)\ncovered/)
    end

    it 'does not retry other errors' do
      calls = 0
      expect { Raider.eventually(timeout: 1) { (calls += 1) && raise(ArgumentError, 'boom') } }
        .to raise_error(ArgumentError)
      expect(calls).to eq(1)
    end
  end
end
