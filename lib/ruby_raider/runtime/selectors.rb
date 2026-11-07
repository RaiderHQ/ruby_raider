# frozen_string_literal: true

require_relative 'config'

module Raider
  # Builds the XPath and CSS strings behind the label, placeholder, alt,
  # title, text and test_id locator keys. Every caller-supplied value passes
  # through xpath_literal or the CSS escaper; nothing else is interpolated.
  module Selectors
    ATTRIBUTE_NAME = /\A[A-Za-z_][\w-]*\z/
    LABEL_CONTROLS = %w[input textarea select button meter output progress]
                     .map { |tag| "self::#{tag}" }.join(' or ').freeze
    EXCLUDED_TEXT = 'not(self::script or self::style or self::noscript or self::template or self::title or self::head) ' \
                    'and not(ancestor::head)'

    module_function

    def xpath_literal(string)
      value = string.to_s
      return "'#{value}'" unless value.include?("'")
      return %("#{value}") unless value.include?('"')

      parts = value.split("'", -1).map { |part| "'#{part}'" }
      "concat(#{parts.join(%q(, "'", ))})"
    end

    def label(value, exact:)
      literal = xpath_literal(value)
      [
        ".//*[@id = //label[#{match('.', literal, exact)}]/@for]",
        ".//label[#{match('.', literal, exact)}]//*[#{LABEL_CONTROLS}]",
        ".//*[#{match('@aria-label', literal, exact)}]",
        ".//*[@aria-labelledby and #{match('string(id(@aria-labelledby))', literal, exact)}]"
      ].join(' | ')
    end

    def text(value, exact:)
      matcher = match('.', xpath_literal(value), exact)
      candidate = "#{EXCLUDED_TEXT} and #{matcher}"
      ".//*[#{candidate} and not(.//*[#{candidate}])]"
    end

    def attribute_css(name, value, exact:)
      raise ArgumentError, "invalid attribute name: #{name}" unless name.to_s.match?(ATTRIBUTE_NAME)

      escaped = value.to_s.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }
      "[#{name}#{exact ? '=' : '*='}\"#{escaped}\"]"
    end

    def test_id(value)
      attribute_css(Raider.test_id_attribute, value, exact: true)
    end

    def match(expression, literal, exact)
      return "normalize-space(#{expression}) = #{literal}" if exact

      "contains(normalize-space(#{expression}), #{literal})"
    end
  end
end
