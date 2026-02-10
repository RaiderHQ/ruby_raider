# frozen_string_literal: true

require_relative 'template_renderer/partial_cache'
require_relative 'template_renderer/partial_resolver'
require_relative 'template_renderer/template_error'

# Template rendering module for Ruby Raider generators
#
# Provides a clean partial() helper for including ERB templates with:
# - Automatic caching of compiled ERB objects (10x performance improvement)
# - Context-aware path resolution (relative to caller, then all source_paths)
# - Helpful error messages when partials are missing
# - Flexible whitespace handling (trim_mode, strip options)
#
# Usage in templates:
#   <%= partial('screenshot') %>                    # Default: trim_mode: '-', no strip
#   <%= partial('screenshot', strip: true) %>       # With .strip!
#   <%= partial('screenshot', trim: false) %>       # No trim_mode
#   <%= partial('driver_config', trim_mode: '<>') %> # Custom trim_mode
#
# The partial() method automatically has access to all generator instance
# variables and methods (cucumber?, mobile?, selenium?, etc.) through binding.
module TemplateRenderer
  # Render a partial template with caching and smart path resolution
  #
  # @param name [String] Partial name without .tt extension (e.g., 'screenshot')
  # @param options [Hash] Rendering options
  # @option options [String, nil] :trim_mode ERB trim mode (default: '-')
  #   - '-'  : Trim lines ending with -%>
  #   - '<>' : Omit newlines for lines starting with <% and ending with %>
  #   - nil  : No trimming
  # @option options [Boolean] :strip Whether to call .strip! on result (default: false)
  # @option options [Boolean] :trim Whether to use trim_mode (default: true)
  #
  # @return [String] Rendered template content
  #
  # @example Basic usage
  #   <%= partial('screenshot') %>
  #
  # @example With strip
  #   <%= partial('screenshot', strip: true) %>
  #
  # @example No trim mode
  #   <%= partial('quit_driver', trim: false) %>
  #
  # @raise [TemplateNotFoundError] If partial cannot be found
  # @raise [TemplateRenderError] If rendering fails
  def partial(name, options = {})
    # Default options
    options = {
      trim_mode: '-',
      strip: false,
      trim: true
    }.merge(options)

    # Handle trim: false by setting trim_mode to nil
    options[:trim_mode] = nil if options[:trim] == false

    # Render the partial through the cache
    result = self.class.template_renderer.render_partial(name, binding, options)

    # Apply strip if requested
    options[:strip] ? result.strip : result
  end

  # Module hook for including in classes
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Class methods added to the including class
  module ClassMethods
    # Get the shared template renderer instance
    # Each generator class gets its own cache instance
    def template_renderer
      @template_renderer ||= PartialCache.new(self)
    end

    # Clear the template cache (useful for testing)
    def clear_template_cache
      @template_renderer&.clear
      @template_renderer = nil
    end

    # Get cache statistics (useful for debugging)
    def template_cache_stats
      @template_renderer&.stats || { size: 0, entries: [], memory_estimate: 0 }
    end
  end
end
