# frozen_string_literal: true

module TemplateRenderer
  # Base error class for all template-related errors
  class TemplateError < StandardError
    attr_reader :partial_name, :searched_paths, :original_error

    def initialize(message, partial_name: nil, searched_paths: nil, original_error: nil)
      @partial_name = partial_name
      @searched_paths = searched_paths || []
      @original_error = original_error
      super(message)
    end
  end

  # Raised when a partial template cannot be found
  class TemplateNotFoundError < TemplateError
    def to_s
      message_parts = ["Partial '#{@partial_name}' not found."]

      if @searched_paths.any?
        message_parts << "\nSearched in:"
        message_parts.concat(@searched_paths.map { |path| "  - #{path}" })
      end

      message_parts.join("\n")
    end
  end

  # Raised when a template has syntax errors or rendering fails
  class TemplateRenderError < TemplateError
    def initialize(message, partial_name:, original_error: nil)
      super(message, partial_name:, original_error:)
    end

    def to_s
      message_parts = ["Error rendering partial '#{@partial_name}': #{message}"]

      if @original_error
        message_parts << "\nOriginal error: #{@original_error.class}: #{@original_error.message}"
        if @original_error.backtrace
          message_parts << "\nBacktrace:"
          message_parts.concat(@original_error.backtrace.first(5).map { |line| "  #{line}" })
        end
      end

      message_parts.join("\n")
    end
  end
end
