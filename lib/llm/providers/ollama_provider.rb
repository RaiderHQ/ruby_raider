# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative '../provider'

module Llm
  module Providers
    # :reek:FeatureEnvy { enabled: false }
    # :reek:TooManyStatements { enabled: false }
    # :reek:ControlParameter { enabled: false }
    class OllamaProvider < Provider
      DEFAULT_MODEL = 'llama3.2'
      DEFAULT_URL = 'http://localhost:11434'
      TIMEOUT = 60

      def initialize(model: nil, url: nil)
        super()
        @model = model || DEFAULT_MODEL
        @base_url = url || DEFAULT_URL
      end

      def complete(prompt, system_prompt: nil)
        uri = URI("#{@base_url}/api/generate")
        body = { model: @model, prompt:, stream: false }
        body[:system] = system_prompt if system_prompt

        response = post_request(uri, body)
        return nil unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)['response']
      rescue StandardError => e
        warn "[Ruby Raider] Ollama error: #{e.message}"
        nil
      end

      def available?
        uri = URI("#{@base_url}/api/tags")
        response = Net::HTTP.get_response(uri)
        response.is_a?(Net::HTTPSuccess)
      rescue StandardError
        warn '[Ruby Raider] Ollama not reachable. Start it with: ollama serve'
        false
      end

      private

      def post_request(uri, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = TIMEOUT
        http.open_timeout = 10
        request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        request.body = JSON.generate(body)
        http.request(request)
      end
    end
  end
end
