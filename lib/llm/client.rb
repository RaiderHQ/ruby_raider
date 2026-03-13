# frozen_string_literal: true

require 'net/http'
require_relative 'config'

module Llm
  # Facade for LLM completion with retry logic and graceful fallback.
  # Returns nil on any failure — callers should always have a non-AI fallback.
  # :reek:TooManyStatements { enabled: false }
  # :reek:DuplicateMethodCall { enabled: false }
  # :reek:UncommunicativeVariableName { enabled: false }
  module Client
    MAX_RETRIES = 3
    BASE_DELAY = 1

    # Only retry on transient network errors, not configuration or API errors
    RETRYABLE_ERRORS = [
      Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
      Errno::ECONNRESET, Errno::ETIMEDOUT, SocketError
    ].freeze

    class << self
      def complete(prompt, system_prompt: nil)
        provider = build_provider
        return nil unless provider

        attempt = 0
        begin
          attempt += 1
          provider.complete(prompt, system_prompt:)
        rescue *RETRYABLE_ERRORS => e
          if attempt < MAX_RETRIES
            sleep(BASE_DELAY * (2**(attempt - 1)))
            retry
          end
          warn "[Ruby Raider] LLM failed after #{MAX_RETRIES} attempts: #{e.message}"
          nil
        rescue StandardError => e
          warn "[Ruby Raider] LLM error: #{e.message}"
          nil
        end
      end

      def available?
        config = Config.new
        return false unless config.configured?

        provider = config.build_provider
        provider&.available? || false
      end

      def status
        config = Config.new
        return { configured: false, provider: nil } unless config.configured?

        provider = config.build_provider
        {
          configured: true,
          provider: config.provider_name,
          model: config.model,
          available: provider&.available? || false
        }
      end

      private

      def build_provider
        config = Config.new
        unless config.configured?
          warn '[Ruby Raider] No LLM configured. Use: raider u llm ollama'
          return nil
        end
        provider = config.build_provider
        unless provider&.available?
          warn "[Ruby Raider] LLM provider '#{config.provider_name}' is not available"
          return nil
        end
        provider
      end
    end
  end
end
