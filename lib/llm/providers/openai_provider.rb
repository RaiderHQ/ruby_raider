# frozen_string_literal: true

require_relative '../provider'

module Llm
  module Providers
    # :reek:FeatureEnvy { enabled: false }
    class OpenaiProvider < Provider
      DEFAULT_MODEL = 'gpt-4o-mini'

      def initialize(api_key:, model: nil)
        super()
        @api_key = api_key
        @model = model || DEFAULT_MODEL
      end

      def complete(prompt, system_prompt: nil)
        client = build_client
        messages = build_messages(prompt, system_prompt)
        response = client.chat(parameters: { model: @model, messages: messages, temperature: 0.2 })
        response.dig('choices', 0, 'message', 'content')
      rescue StandardError => e
        warn "[Ruby Raider] OpenAI error: #{e.message}"
        nil
      end

      def available?
        require 'openai'
        !@api_key.nil? && !@api_key.empty?
      rescue LoadError
        warn '[Ruby Raider] Install ruby-openai gem: gem install ruby-openai'
        false
      end

      private

      def build_client
        require 'openai'
        OpenAI::Client.new(access_token: @api_key)
      end
    end
  end
end
