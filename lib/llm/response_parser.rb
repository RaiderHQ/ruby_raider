# frozen_string_literal: true

require 'json'

module Llm
  # Extracts JSON from LLM responses, handling markdown wrapping and malformed output.
  # Returns nil on parse failure — callers should fall back to non-AI path.
  module ResponseParser
    module_function

    def parse_json(response)
      return nil if response.nil? || response.strip.empty?

      json_str = extract_json(response)
      result = JSON.parse(json_str, symbolize_names: true)
      result.is_a?(Hash) ? result : nil
    rescue JSON::ParserError
      nil
    end

    def extract_elements(response)
      parsed = parse_json(response)
      return nil unless parsed && parsed[:elements].is_a?(Array)

      parsed[:elements].map { |el| normalize_element(el) }.compact
    end

    def extract_scenarios(response)
      parsed = parse_json(response)
      return nil unless parsed && parsed[:scenarios].is_a?(Array)

      parsed[:scenarios]
    end

    # :reek:FeatureEnvy { enabled: false }
    def normalize_element(element)
      return nil unless element[:name] && element[:type] && element[:locator]

      locator = element[:locator]
      locator = { type: locator[:type]&.to_sym, value: locator[:value] } if locator.is_a?(Hash)

      {
        name: element[:name].to_s.gsub(/[^a-z0-9_]/i, '_').downcase,
        type: element[:type].to_sym,
        locator: locator,
        purpose: element[:purpose],
        input_type: element[:input_type],
        text: element[:text]
      }.compact
    end

    def extract_json(text)
      # Try raw JSON first
      stripped = text.strip
      return stripped if stripped.start_with?('{')

      # Try markdown code block
      match = text.match(/```(?:json)?\s*\n?(.*?)\n?\s*```/m)
      return match[1].strip if match

      # Try finding first { ... } block
      brace_match = text.match(/(\{.*\})/m)
      return brace_match[1] if brace_match

      text
    end
  end
end
