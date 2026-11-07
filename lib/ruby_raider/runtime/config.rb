# frozen_string_literal: true

require 'yaml'

# Runtime configuration. Precedence per key: explicit setter, then env,
# then config/config.yml, then the default.
module Raider
  CONFIG_FILE = 'config/config.yml'
  FALSY = %w[off false 0 no].freeze

  # Load-order and configuration mistakes.
  class Error < StandardError; end

  class << self
    def strict
      resolve(:strict, 'RAIDER_STRICT', true) { |value| truthy?(value) }
    end

    def actionability
      resolve(:actionability, 'RAIDER_ACTIONABILITY', true) { |value| truthy?(value) }
    end

    def timeout
      resolve(:timeout, 'RAIDER_TIMEOUT', 10) { |value| number(value) }
    end

    def test_id_attribute
      resolve(:test_id_attribute, 'RAIDER_TEST_ID_ATTRIBUTE', 'data-testid', &:to_s)
    end

    attr_writer :strict, :actionability, :timeout, :test_id_attribute

    # Any object (or nil) receiving action events; see Raider::Observer.
    attr_accessor :observer

    def reset
      @strict = @actionability = @timeout = @test_id_attribute = nil
      @observer = nil
      @file_config = nil
    end

    private

    def resolve(key, env_name, default)
      explicit = instance_variable_get("@#{key}")
      return explicit unless explicit.nil?

      raw = ENV.fetch(env_name, nil)
      raw = file_config[key.to_s] if raw.nil? || raw.empty?
      raw.nil? ? default : yield(raw)
    end

    def file_config
      @file_config ||= load_file
    end

    def load_file
      return {} unless File.exist?(CONFIG_FILE)

      data = YAML.safe_load_file(CONFIG_FILE, permitted_classes: [Symbol])
      data.is_a?(Hash) ? data : {}
    rescue Psych::Exception => e
      raise Error, "cannot read #{CONFIG_FILE}: #{e.message}"
    end

    def truthy?(value)
      return value if [true, false].include?(value)

      !FALSY.include?(value.to_s.strip.downcase)
    end

    def number(value)
      return value if value.is_a?(Numeric)

      float = Float(value)
      float == float.to_i ? float.to_i : float
    end
  end
end
