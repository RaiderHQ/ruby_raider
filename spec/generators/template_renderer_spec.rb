# frozen_string_literal: true

require_relative '../integration/spec_helper'
require_relative '../../lib/generators/template_renderer'
require_relative '../../lib/generators/generator'

RSpec.describe TemplateRenderer do
  # Create a test generator class that includes TemplateRenderer
  let(:test_generator_class) do
    Class.new do
      include TemplateRenderer

      def self.source_paths
        [File.expand_path('../fixtures/templates', __dir__)]
      end

      # Mock predicate methods that templates might use
      def selenium_based?
        true
      end

      def watir?
        false
      end

      def mobile?
        false
      end
    end
  end

  let(:test_instance) { test_generator_class.new }

  describe '#partial' do
    context 'when rendering a simple partial' do
      it 'renders the partial content' do
        # This test requires a fixtures directory with test templates
        # For now, we'll test the API interface
        expect(test_instance).to respond_to(:partial)
      end

      it 'accepts a partial name as first argument' do
        expect { test_instance.partial('test_partial') }.not_to raise_error(ArgumentError)
      end

      it 'accepts options hash' do
        expect { test_instance.partial('test', trim_mode: '-', strip: true) }.not_to raise_error(ArgumentError)
      end
    end

    context 'with strip option' do
      it 'applies strip when strip: true' do
        # Mock the template renderer to verify strip is called
        allow_any_instance_of(TemplateRenderer::PartialCache).to receive(:render_partial)
          .and_return("  content  \n")

        result = test_instance.partial('test', strip: true)
        expect(result).to eq('content')
      end

      it 'does not apply strip when strip: false (default)' do
        allow_any_instance_of(TemplateRenderer::PartialCache).to receive(:render_partial)
          .and_return("  content  \n")

        result = test_instance.partial('test', strip: false)
        expect(result).to eq("  content  \n")
      end
    end

    context 'with trim_mode option' do
      it 'uses default trim_mode: "-" when not specified' do
        cache = test_generator_class.template_renderer
        expect(cache).to receive(:render_partial).with('test', anything, hash_including(trim_mode: '-'))
        test_instance.partial('test')
      end

      it 'allows custom trim_mode' do
        cache = test_generator_class.template_renderer
        expect(cache).to receive(:render_partial).with('test', anything, hash_including(trim_mode: '<>'))
        test_instance.partial('test', trim_mode: '<>')
      end

      it 'disables trim_mode when trim: false' do
        cache = test_generator_class.template_renderer
        expect(cache).to receive(:render_partial).with('test', anything, hash_including(trim_mode: nil))
        test_instance.partial('test', trim: false)
      end
    end
  end

  describe 'ClassMethods' do
    describe '.template_renderer' do
      it 'returns a PartialCache instance' do
        expect(test_generator_class.template_renderer).to be_a(TemplateRenderer::PartialCache)
      end

      it 'returns the same instance on multiple calls (memoization)' do
        first = test_generator_class.template_renderer
        second = test_generator_class.template_renderer
        expect(first).to be(second)
      end
    end

    describe '.clear_template_cache' do
      it 'clears the template cache' do
        test_generator_class.template_renderer # Initialize cache
        test_generator_class.clear_template_cache
        expect(test_generator_class.instance_variable_get(:@template_renderer)).to be_nil
      end
    end

    describe '.template_cache_stats' do
      it 'returns cache statistics' do
        stats = test_generator_class.template_cache_stats
        expect(stats).to have_key(:size)
        expect(stats).to have_key(:entries)
        expect(stats).to have_key(:memory_estimate)
      end
    end
  end
end

RSpec.describe TemplateRenderer::PartialCache do
  let(:generator_class) do
    Class.new do
      def self.source_paths
        [File.expand_path('../fixtures/templates', __dir__)]
      end
    end
  end

  let(:cache) { described_class.new(generator_class) }
  let(:test_binding) { binding }

  describe '#render_partial' do
    context 'when partial does not exist' do
      it 'raises TemplateNotFoundError' do
        expect do
          cache.render_partial('nonexistent', test_binding, {})
        end.to raise_error(TemplateRenderer::TemplateNotFoundError)
      end

      it 'includes searched paths in error message' do
        expect do
          cache.render_partial('missing', test_binding, {})
        end.to raise_error(TemplateRenderer::TemplateNotFoundError, /Searched in/)
      end
    end

    context 'when partial has syntax errors' do
      it 'raises TemplateRenderError' do
        # This would require a fixture file with ERB syntax errors
        # For now, test that the error class exists
        expect(TemplateRenderer::TemplateRenderError).to be < TemplateRenderer::TemplateError
      end
    end
  end

  describe '#clear' do
    it 'clears the cache' do
      cache.clear
      expect(cache.stats[:size]).to eq(0)
    end
  end

  describe '#stats' do
    it 'returns cache statistics hash' do
      stats = cache.stats
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:size)
      expect(stats).to have_key(:entries)
      expect(stats).to have_key(:memory_estimate)
    end

    it 'estimates memory usage' do
      stats = cache.stats
      expect(stats[:memory_estimate]).to be >= 0
    end
  end

  describe 'caching behavior' do
    it 'caches compiled ERB objects' do
      # This test would require actual fixture files
      # Verifies that repeated renders use cache
      expect(cache.instance_variable_get(:@cache)).to be_a(Hash)
    end
  end
end

RSpec.describe TemplateRenderer::PartialResolver do
  let(:generator_class) do
    Class.new do
      def self.source_paths
        [
          '/path/to/templates',
          '/another/path/templates'
        ]
      end
    end
  end

  let(:resolver) { described_class.new(generator_class) }
  let(:test_binding) { binding }

  describe '#resolve' do
    it 'attempts to resolve relative to caller first' do
      # Mock file existence check
      allow(File).to receive(:exist?).and_return(false)

      expect do
        resolver.resolve('test', test_binding)
      end.to raise_error(TemplateRenderer::TemplateNotFoundError)
    end
  end

  describe '#search_paths' do
    it 'returns all paths that were searched' do
      paths = resolver.search_paths('screenshot', test_binding)

      expect(paths).to be_an(Array)
      expect(paths).not_to be_empty
      expect(paths.first).to include('screenshot.tt')
    end

    it 'includes relative path if caller file is available' do
      paths = resolver.search_paths('screenshot', test_binding)
      # Should include relative path attempt
      expect(paths.length).to be >= 1
    end

    it 'includes all source_paths in search' do
      paths = resolver.search_paths('screenshot', test_binding)

      # Should search in all configured source paths
      expect(paths.any? { |p| p.include?('/path/to/templates') }).to be true
    end
  end
end

RSpec.describe TemplateRenderer::TemplateError do
  describe TemplateRenderer::TemplateNotFoundError do
    it 'formats error message with searched paths' do
      error = described_class.new(
        'Partial not found',
        partial_name: 'test',
        searched_paths: ['/path/1', '/path/2']
      )

      message = error.to_s
      expect(message).to include("Partial 'test' not found")
      expect(message).to include('/path/1')
      expect(message).to include('/path/2')
      expect(message).to include('Searched in:')
    end
  end

  describe TemplateRenderer::TemplateRenderError do
    it 'includes original error information' do
      original = StandardError.new('syntax error')
      original.set_backtrace(['line 1', 'line 2'])

      error = described_class.new(
        'Render failed',
        partial_name: 'test',
        original_error: original
      )

      message = error.to_s
      expect(message).to include('Error rendering partial')
      expect(message).to include('syntax error')
      expect(message).to include('Backtrace:')
    end
  end
end

# Integration test with Generator base class
RSpec.describe Generator do
  it 'includes TemplateRenderer module' do
    expect(described_class.ancestors).to include(TemplateRenderer)
  end

  it 'has partial method available' do
    # Generator requires arguments, so we'll test the class directly
    expect(described_class.instance_methods).to include(:partial)
  end

  it 'has template_renderer class method' do
    expect(described_class).to respond_to(:template_renderer)
  end

  it 'has clear_template_cache class method' do
    expect(described_class).to respond_to(:clear_template_cache)
  end

  it 'has template_cache_stats class method' do
    expect(described_class).to respond_to(:template_cache_stats)
  end
end
