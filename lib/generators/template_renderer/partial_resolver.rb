# frozen_string_literal: true

require_relative 'template_error'

module TemplateRenderer
  # Resolves partial template paths with context-aware searching
  #
  # Resolution strategy:
  # 1. Try relative to calling template: ./partials/{name}.tt
  # 2. Fall back to all Generator.source_paths searching for partials/{name}.tt
  class PartialResolver
    PARTIAL_EXTENSION = '.tt'
    PARTIALS_DIR = 'partials'

    def initialize(generator_class)
      @generator_class = generator_class
    end

    # Resolve a partial name to its absolute file path
    #
    # @param name [String] The partial name (without .tt extension)
    # @param binding [Binding] The binding context from the caller
    # @return [String] Absolute path to the partial file
    # @raise [TemplateNotFoundError] If partial cannot be found
    def resolve(name, binding)
      caller_file = caller_file_from_binding(binding)
      partial_filename = "#{name}#{PARTIAL_EXTENSION}"

      # Try relative to caller first
      if caller_file
        relative_path = File.join(File.dirname(caller_file), PARTIALS_DIR, partial_filename)
        return File.expand_path(relative_path) if File.exist?(relative_path)
      end

      # Fall back to searching all source paths
      searched = search_source_paths(partial_filename)
      return searched[:found] if searched[:found]

      # Not found - raise with helpful error
      raise TemplateNotFoundError.new(
        "Partial '#{name}' not found",
        partial_name: name,
        searched_paths: search_paths(name, binding)
      )
    end

    # Get all paths that were searched (for error messages)
    def search_paths(name, binding)
      paths = []
      partial_filename = "#{name}#{PARTIAL_EXTENSION}"

      # Add relative path if available
      caller_file = caller_file_from_binding(binding)
      if caller_file
        relative_path = File.join(File.dirname(caller_file), PARTIALS_DIR, partial_filename)
        paths << relative_path
      end

      # Add all source path possibilities (including subdirectories)
      source_paths.each do |source_path|
        paths << File.join(source_path, PARTIALS_DIR, partial_filename)

        # Also include subdirectories (e.g., templates/common/partials/, templates/helpers/partials/)
        Dir.glob(File.join(source_path, '*', PARTIALS_DIR)).each do |subdir|
          paths << File.join(subdir, partial_filename)
        end
      end

      paths
    end

    private

    # Extract the calling template file from binding context
    def caller_file_from_binding(binding)
      binding.eval('__FILE__')
    rescue StandardError
      nil
    end

    # Search all Generator.source_paths for the partial
    # Checks both source_path/partials/ and source_path/*/partials/
    def search_source_paths(partial_filename)
      source_paths.each do |source_path|
        # First try direct partials directory
        full_path = File.join(source_path, PARTIALS_DIR, partial_filename)
        return { found: File.expand_path(full_path), searched: [full_path] } if File.exist?(full_path)

        # Then try subdirectories (e.g., templates/common/partials/, templates/helpers/partials/)
        Dir.glob(File.join(source_path, '*', PARTIALS_DIR, partial_filename)).each do |path|
          return { found: File.expand_path(path), searched: [path] } if File.exist?(path)
        end
      end

      { found: nil, searched: [] }
    end

    # Get all configured source paths from the generator class
    def source_paths
      @source_paths ||= @generator_class.source_paths || []
    end
  end
end
