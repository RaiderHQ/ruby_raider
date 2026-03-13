# frozen_string_literal: true

require 'uri'
require 'net/http'

# :reek:TooManyStatements { enabled: false }
# :reek:FeatureEnvy { enabled: false }
class UrlAnalyzer
  INTERACTIVE_TAGS = %w[input select textarea button].freeze

  attr_reader :url, :page_name, :elements

  def initialize(url, name_override: nil, ai: false) # rubocop:disable Naming/MethodParameterName
    @url = url
    @uri = URI.parse(url)
    @page_name = name_override || derive_page_name
    @elements = []
    @ai = ai
  end

  def analyze
    html = fetch_html
    if @ai
      ai_elements = analyze_with_llm(html)
      @elements = ai_elements if ai_elements
    end
    parse_elements(html) if @elements.empty?
    self
  end

  def to_h
    { page_name: @page_name, url: @url, url_path: @uri.path, elements: @elements }
  end

  private

  def fetch_html
    response = Net::HTTP.get_response(@uri)
    response.body
  rescue StandardError => e
    raise "Failed to fetch #{@url}: #{e.message}"
  end

  def parse_elements(html)
    # Simple regex-based HTML parsing (no external dependency needed)
    parse_inputs(html)
    parse_selects(html)
    parse_textareas(html)
    parse_buttons(html)
    parse_links(html)
  end

  def parse_inputs(html)
    html.scan(/<input\s+([^>]*)>/i).each do |match|
      attrs = parse_attributes(match[0])
      next if %w[hidden submit].include?(attrs['type'])

      @elements << build_element(
        name: attrs['name'] || attrs['id'] || attrs['placeholder'] || 'input',
        type: :input,
        input_type: attrs['type'] || 'text',
        locator: best_locator(attrs)
      )
    end
  end

  def parse_selects(html)
    html.scan(/<select\s+([^>]*)>/i).each do |match|
      attrs = parse_attributes(match[0])
      @elements << build_element(
        name: attrs['name'] || attrs['id'] || 'select',
        type: :select,
        locator: best_locator(attrs)
      )
    end
  end

  def parse_textareas(html)
    html.scan(/<textarea\s+([^>]*)>/i).each do |match|
      attrs = parse_attributes(match[0])
      @elements << build_element(
        name: attrs['name'] || attrs['id'] || 'textarea',
        type: :textarea,
        locator: best_locator(attrs)
      )
    end
  end

  def parse_buttons(html)
    html.scan(%r{<button\s+([^>]*)>([^<]*)</button>}i).each do |match|
      attrs = parse_attributes(match[0])
      text = match[1].strip
      @elements << build_element(
        name: attrs['id'] || attrs['name'] || text.downcase.gsub(/\s+/, '_') || 'button',
        type: :button,
        text:,
        locator: best_locator(attrs, text:)
      )
    end

    html.scan(/<input\s+([^>]*type=["']submit["'][^>]*)>/i).each do |match|
      attrs = parse_attributes(match[0])
      @elements << build_element(
        name: attrs['id'] || attrs['name'] || attrs['value']&.downcase&.gsub(/\s+/, '_') || 'submit',
        type: :submit,
        text: attrs['value'] || 'Submit',
        locator: best_locator(attrs)
      )
    end
  end

  def parse_links(html)
    html.scan(%r{<a\s+([^>]*)>([^<]*)</a>}i).first(5)&.each do |match|
      attrs = parse_attributes(match[0])
      text = match[1].strip
      next if text.empty?

      @elements << build_element(
        name: text.downcase.gsub(/\s+/, '_'),
        type: :link,
        text:,
        locator: best_locator(attrs, text:)
      )
    end
  end

  def parse_attributes(attr_string)
    attrs = {}
    attr_string.scan(/([\w-]+)=["']([^"']*)["']/).each do |key, value|
      attrs[key] = value
    end
    attrs
  end

  def best_locator(attrs, text: nil)
    if attrs['id']
      { type: :id, value: attrs['id'] }
    elsif attrs['name']
      { type: :name, value: attrs['name'] }
    elsif attrs['class'] && !attrs['class'].empty?
      { type: :css, value: ".#{attrs['class'].split.first}" }
    elsif text && !text.empty?
      { type: :xpath, value: "//#{infer_tag(attrs)}[contains(text(), '#{text}')]" }
    else
      { type: :css, value: attrs.first&.last || 'unknown' }
    end
  end

  def infer_tag(attrs)
    return 'button' if attrs['type'] == 'button' || attrs['type'] == 'submit'
    return 'a' if attrs['href']

    '*'
  end

  def build_element(name:, type:, locator:, **extra)
    clean_name = name.to_s.gsub(/[^a-z0-9_]/i, '_').gsub(/_+/, '_').downcase.delete_prefix('_').delete_suffix('_')
    { name: clean_name, type:, locator: }.merge(extra)
  end

  def analyze_with_llm(html)
    require_relative '../llm/client'
    require_relative '../llm/prompts'
    require_relative '../llm/response_parser'

    return nil unless Llm::Client.available?

    response = Llm::Client.complete(
      Llm::Prompts.analyze_page(html, @url),
      system_prompt: Llm::Prompts.system_prompt
    )
    Llm::ResponseParser.extract_elements(response)
  end

  def derive_page_name
    path = @uri.path.to_s.gsub(%r{^/|/$}, '')
    return 'home' if path.empty?

    path.split('/').last.gsub(/[^a-z0-9]/i, '_').downcase
  end
end
