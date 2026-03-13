# frozen_string_literal: true

require 'ripper'

# :reek:TooManyStatements { enabled: false }
class PageIntrospector
  SKIP_METHODS = %w[initialize url to_s inspect].freeze

  attr_reader :class_name, :methods

  def initialize(file_path)
    @source = File.read(file_path)
    @class_name = extract_class_name
    @methods = extract_public_methods
  end

  private

  def extract_class_name
    match = @source.match(/class\s+(\w+)/)
    match ? match[1] : 'UnknownPage'
  end

  # :reek:FeatureEnvy { enabled: false }
  def extract_public_methods
    in_private = false
    results = []

    @source.each_line do |line|
      stripped = line.strip
      in_private = true if stripped.match?(/^\s*(private|protected)\s*$/)
      next if in_private

      match = stripped.match(/^\s*def\s+(\w+)(\(([^)]*)\))?/)
      next unless match

      method_name = match[1]
      next if SKIP_METHODS.include?(method_name)
      next if method_name.start_with?('_')

      params = match[3]&.split(',')&.map(&:strip) || []
      results << { name: method_name, params: }
    end

    results
  end
end
