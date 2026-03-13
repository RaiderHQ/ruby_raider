# frozen_string_literal: true

require 'yaml'

module Llm
  # Reads LLM configuration from env vars and config/config.yml
  # Env vars take precedence over config file values.
  class Config
    PROVIDERS = %w[openai anthropic ollama].freeze

    attr_reader :provider_name, :api_key, :model, :url

    def initialize
      @provider_name = env('RUBY_RAIDER_LLM_PROVIDER') || config_value('llm_provider')
      @api_key = env('RUBY_RAIDER_LLM_API_KEY') || config_value('llm_api_key')
      @model = env('RUBY_RAIDER_LLM_MODEL') || config_value('llm_model')
      @url = env('RUBY_RAIDER_LLM_URL') || config_value('llm_url')
    end

    def configured?
      return false unless @provider_name && PROVIDERS.include?(@provider_name)
      return true if @provider_name == 'ollama'

      !@api_key.nil? && !@api_key.empty?
    end

    def build_provider
      return nil unless configured?

      case @provider_name
      when 'openai'
        require_relative 'providers/openai_provider'
        Providers::OpenaiProvider.new(api_key: @api_key, model: @model)
      when 'anthropic'
        require_relative 'providers/anthropic_provider'
        Providers::AnthropicProvider.new(api_key: @api_key, model: @model)
      when 'ollama'
        require_relative 'providers/ollama_provider'
        Providers::OllamaProvider.new(model: @model, url: @url)
      end
    end

    private

    def env(key)
      value = ENV.fetch(key, nil)
      value&.strip&.empty? ? nil : value&.strip
    end

    def config_value(key)
      return nil unless File.exist?('config/config.yml')

      data = YAML.load_file('config/config.yml')
      data&.dig(key)
    end
  end
end
