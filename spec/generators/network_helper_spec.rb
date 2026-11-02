# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'tmpdir'
require 'uri'
require_relative '../../lib/generators/helper_generator'

# Renders network_helper.tt for a selenium/rspec project and loads it.
module NetworkHelperRenderer
  TEMPLATE = File.expand_path('../../lib/generators/templates/helpers/network_helper.tt', __dir__)

  def render_and_load_network_helper
    generator = HelpersGenerator.new(%w[selenium rspec proj])
    rendered = ERB.new(File.read(TEMPLATE), trim_mode: '-').result(generator.instance_eval { binding })
    Dir.mktmpdir('network-helper') do |dir|
      path = File.join(dir, 'network_helper.rb')
      File.write(path, rendered)
      Object.send(:remove_const, :NetworkHelper) if Object.const_defined?(:NetworkHelper)
      load path
    end
  end
end

RSpec.describe 'NetworkHelper::Matcher' do
  include NetworkHelperRenderer

  before { render_and_load_network_helper }

  let(:matcher) { NetworkHelper::Matcher }

  def matches?(url, request_url, http_method = 'GET', **options)
    matcher.new(url, **options).match?(request_url, http_method)
  end

  describe '#match?' do
    it 'matches ** across hosts but not the query' do
      expect(matches?('**/api/users', 'https://a.test/api/users')).to be(true)
      expect(matches?('**/api/users', 'https://a.test/api/users?page=2')).to be(false)
      expect(matches?('**/api/users?*', 'https://a.test/api/users?page=2')).to be(true)
    end

    it 'stops * at a slash' do
      expect(matches?('https://shop.test/api/items/*', 'https://shop.test/api/items/7')).to be(true)
      expect(matches?('https://shop.test/api/items/*', 'https://shop.test/api/items/7/x')).to be(false)
    end

    it 'treats other characters literally' do
      expect(matches?('https://a.test/a.b', 'https://a.test/aXb')).to be(false)
      expect(matches?('https://a.test/a.b', 'https://a.test/a.b')).to be(true)
    end

    it 'matches a Regexp against the full URL' do
      expect(matches?(%r{/api/items/\d+$}, 'https://a.test/api/items/42')).to be(true)
    end

    it 'compares the method case-insensitively, nil matches all' do
      expect(matches?('**/api', 'https://a.test/api', 'GET', method: :post)).to be(false)
      expect(matches?('**/api', 'https://a.test/api', 'POST', method: :post)).to be(true)
      expect(matches?('**/api', 'https://a.test/api', 'DELETE')).to be(true)
    end

    it 'rejects a url that is neither String nor Regexp' do
      expect { matcher.new(42) }.to raise_error(ArgumentError)
    end
  end

  describe '#intercept_patterns' do
    it 'narrows to the literal parts of the glob' do
      expect(matcher.new('**/api/users').intercept_patterns).to be_nil
      expect(matcher.new('https://*.test/api').intercept_patterns).to be_nil
      expect(matcher.new('https://a.test/api/users?*').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'https', hostname: 'a.test', pathname: '/api/users' }])
      expect(matcher.new('https://shop.test/api/*').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'https', hostname: 'shop.test' }])
      expect(matcher.new('http://127.0.0.1:4567/api').intercept_patterns)
        .to eq([{ type: 'pattern', protocol: 'http', hostname: '127.0.0.1', port: '4567', pathname: '/api' }])
    end

    it 'is nil when nothing literal is left' do
      expect(matcher.new(/x/).intercept_patterns).to be_nil
      expect(matcher.new('**').intercept_patterns).to be_nil
    end
  end

  describe 'narrowing never misses a matching URL' do
    let(:urls) do
      %w[https://a.test/api/users https://a.test/api/users?page=2 https://shop.test/api/items/7
         http://127.0.0.1:4567/api http://127.0.0.1:4567/api/x https://b.test/x/api/users https://a.test]
    end
    let(:globs) do
      ['**/api/users', '**/api/users?*', 'https://a.test/api/users?*', 'https://shop.test/api/*',
       'http://127.0.0.1:4567/api', 'http://127.0.0.1:4567/**', 'https://*.test/api/users', '**', 'https://a.test**']
    end

    def covered?(pattern, uri)
      { protocol: uri.scheme, hostname: uri.host, port: uri.port.to_s, pathname: uri.path }.all? do |key, value|
        !pattern.key?(key) || pattern[key] == value
      end
    end

    it 'keeps every URL the glob matches inside a narrowed pattern' do
      globs.each do |glob|
        matcher_for_glob = matcher.new(glob)
        patterns = matcher_for_glob.intercept_patterns
        urls.select { |url| matcher_for_glob.match?(url, 'GET') }.each do |url|
          next if patterns.nil?

          uri = URI(url)
          expect(patterns.any? { |pattern| covered?(pattern, uri) }).to be(true), "#{glob} narrows past #{url}"
        end
      end
    end
  end
end
