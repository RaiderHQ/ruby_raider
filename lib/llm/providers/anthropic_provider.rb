# frozen_string_literal: true

require_relative '../provider'

module Llm
  module Providers
    class AnthropicProvider < Provider
      DEFAULT_MODEL = 'claude-sonnet-4-20250514'

      def initialize(api_key:, model: nil)
        super()
        @api_key = api_key
        @model = model || DEFAULT_MODEL
      end

      def complete(prompt, system_prompt: nil)
        client = build_client
        params = { model: @model, max_tokens: 4096, messages: [{ role: 'user', content: prompt }] }
        params[:system] = system_prompt if system_prompt
        response = client.messages(parameters: params)
        response.dig('content', 0, 'text')
      rescue StandardError => e
        warn "[Ruby Raider] Anthropic error: #{e.message}"
        nil
      end

      def available?
        require 'anthropic'
        !@api_key.nil? && !@api_key.empty?
      rescue LoadError
        warn '[Ruby Raider] Install anthropic gem: gem install anthropic-rb'
        false
      end

      private

      def build_client
        require 'anthropic'
        Anthropic::Client.new(access_token: @api_key)
      end
    end
  end
end
