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

  describe 'eventually' do
    it 'is gone' do
      expect(Raider.respond_to?(:eventually)).to be(false)
      expect(Raider::Wait.respond_to?(:eventually)).to be(false)
    end
  end

  describe '.immediately' do
    it 'returns the block value and flags the block as immediate' do
      expect(Raider::Wait.immediate?).to be(false)
      expect(Raider::Wait.immediately { Raider::Wait.immediate? }).to be(true)
      expect(Raider::Wait.immediate?).to be(false)
    end

    it 'stays immediate when an inner call leaves' do
      Raider::Wait.immediately do
        Raider::Wait.immediately { :inner }
        expect(Raider::Wait.immediate?).to be(true)
      end
    end

    it 'restores the flag when the block raises' do
      expect { Raider::Wait.immediately { raise ArgumentError } }.to raise_error(ArgumentError)
      expect(Raider::Wait.immediate?).to be(false)
    end
  end
end
