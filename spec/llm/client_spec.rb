# frozen_string_literal: true

require_relative '../../lib/llm/client'
require_relative '../../lib/llm/provider'

RSpec.describe Llm::Client do
  let(:mock_provider) { instance_double(Llm::Provider, available?: true) }
  let(:mock_config) { instance_double(Llm::Config, configured?: true, provider_name: 'ollama', model: 'llama3.2') }

  before do
    allow(Llm::Config).to receive(:new).and_return(mock_config)
    allow(mock_config).to receive(:build_provider).and_return(mock_provider)
  end

  describe '.complete' do
    it 'delegates to the provider' do
      allow(mock_provider).to receive(:complete).and_return('AI response')
      result = described_class.complete('test prompt')
      expect(result).to eq('AI response')
    end

    it 'returns nil when not configured' do
      allow(mock_config).to receive(:configured?).and_return(false)
      expect(described_class.complete('test prompt')).to be_nil
    end

    it 'returns nil when provider is not available' do
      allow(mock_provider).to receive(:available?).and_return(false)
      expect(described_class.complete('test prompt')).to be_nil
    end

    it 'retries on failure and returns nil after max retries' do
      allow(mock_provider).to receive(:complete).and_raise(StandardError, 'network error')
      allow(described_class).to receive(:sleep) # skip actual sleep
      expect(described_class.complete('test prompt')).to be_nil
    end

    it 'passes system_prompt to provider' do
      allow(mock_provider).to receive(:complete).and_return('ok')
      result = described_class.complete('prompt', system_prompt: 'system')
      expect(result).to eq('ok')
      expect(mock_provider).to have_received(:complete).with('prompt', system_prompt: 'system')
    end
  end

  describe '.available?' do
    it 'returns true when provider is configured and available' do
      expect(described_class).to be_available
    end

    it 'returns false when not configured' do
      allow(mock_config).to receive(:configured?).and_return(false)
      expect(described_class).not_to be_available
    end

    it 'returns false when provider is not available' do
      allow(mock_provider).to receive(:available?).and_return(false)
      expect(described_class).not_to be_available
    end
  end

  describe '.status' do
    it 'returns configured status with details' do
      allow(mock_provider).to receive(:available?).and_return(true)
      status = described_class.status
      expect(status[:configured]).to be true
      expect(status[:provider]).to eq('ollama')
      expect(status[:model]).to eq('llama3.2')
      expect(status[:available]).to be true
    end

    it 'returns unconfigured status' do
      allow(mock_config).to receive(:configured?).and_return(false)
      status = described_class.status
      expect(status[:configured]).to be false
      expect(status[:provider]).to be_nil
    end
  end
end
