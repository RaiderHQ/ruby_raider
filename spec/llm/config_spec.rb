# frozen_string_literal: true

require_relative '../../lib/llm/config'

RSpec.describe Llm::Config do
  before do
    allow(ENV).to receive(:fetch).and_call_original
    %w[RUBY_RAIDER_LLM_PROVIDER RUBY_RAIDER_LLM_API_KEY RUBY_RAIDER_LLM_MODEL RUBY_RAIDER_LLM_URL].each do |key|
      allow(ENV).to receive(:fetch).with(key, nil).and_return(nil)
    end
    allow(File).to receive(:exist?).with('config/config.yml').and_return(false)
  end

  describe '#configured?' do
    it 'returns false when no provider is set' do
      expect(described_class.new).not_to be_configured
    end

    it 'returns false for unknown provider' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('unknown')
      expect(described_class.new).not_to be_configured
    end

    it 'returns true for ollama without api key' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('ollama')
      expect(described_class.new).to be_configured
    end

    it 'returns false for openai without api key' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('openai')
      expect(described_class.new).not_to be_configured
    end

    it 'returns true for openai with api key' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('openai')
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_API_KEY', nil).and_return('sk-test')
      expect(described_class.new).to be_configured
    end

    it 'returns true for anthropic with api key' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('anthropic')
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_API_KEY', nil).and_return('sk-ant-test')
      expect(described_class.new).to be_configured
    end
  end

  describe '#build_provider' do
    it 'returns nil when not configured' do
      expect(described_class.new.build_provider).to be_nil
    end

    it 'builds OpenaiProvider for openai' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('openai')
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_API_KEY', nil).and_return('sk-test')
      provider = described_class.new.build_provider
      expect(provider).to be_a(Llm::Providers::OpenaiProvider)
    end

    it 'builds AnthropicProvider for anthropic' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('anthropic')
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_API_KEY', nil).and_return('sk-ant-test')
      provider = described_class.new.build_provider
      expect(provider).to be_a(Llm::Providers::AnthropicProvider)
    end

    it 'builds OllamaProvider for ollama' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('ollama')
      provider = described_class.new.build_provider
      expect(provider).to be_a(Llm::Providers::OllamaProvider)
    end
  end

  describe 'config file fallback' do
    it 'reads from config/config.yml when env vars are not set' do
      allow(File).to receive(:exist?).with('config/config.yml').and_return(true)
      allow(YAML).to receive(:load_file).with('config/config.yml').and_return(
        'llm_provider' => 'ollama',
        'llm_model' => 'codellama'
      )
      config = described_class.new
      expect(config.provider_name).to eq('ollama')
      expect(config.model).to eq('codellama')
    end

    it 'env vars take precedence over config file' do
      allow(ENV).to receive(:fetch).with('RUBY_RAIDER_LLM_PROVIDER', nil).and_return('anthropic')
      allow(File).to receive(:exist?).with('config/config.yml').and_return(true)
      allow(YAML).to receive(:load_file).with('config/config.yml').and_return('llm_provider' => 'ollama')
      expect(described_class.new.provider_name).to eq('anthropic')
    end
  end
end
