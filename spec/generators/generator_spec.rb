# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/generators/generator'

RSpec.describe Generator do
  describe '#ruby_version' do
    it 'returns the default version when no ruby_version arg is present' do
      generator = described_class.new(%w[selenium rspec test_project])
      expect(generator.ruby_version).to eq('3.4')
    end

    it 'returns the specified version from args' do
      generator = described_class.new(%w[selenium rspec test_project ruby_version:3.3])
      expect(generator.ruby_version).to eq('3.3')
    end

    it 'handles version with multiple colons gracefully' do
      generator = described_class.new(%w[selenium rspec test_project ruby_version:3.2])
      expect(generator.ruby_version).to eq('3.2')
    end
  end
end
