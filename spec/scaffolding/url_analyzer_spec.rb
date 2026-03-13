# frozen_string_literal: true

require_relative '../../lib/scaffolding/url_analyzer'

RSpec.describe UrlAnalyzer do
  let(:sample_html) do
    <<~HTML
      <html>
        <body>
          <form>
            <input type="text" id="username" name="username" />
            <input type="password" id="password" name="password" />
            <input type="hidden" name="csrf" value="token123" />
            <select id="role" name="role"><option>Admin</option></select>
            <textarea id="bio" name="bio"></textarea>
            <button id="login-btn">Log In</button>
            <input type="submit" id="submit-btn" value="Submit" />
            <a href="/forgot">Forgot Password</a>
          </form>
        </body>
      </html>
    HTML
  end

  before do
    stub_request = instance_double(Net::HTTPSuccess, body: sample_html)
    allow(Net::HTTP).to receive(:get_response).and_return(stub_request)
  end

  subject(:analyzer) { described_class.new('https://example.com/login') }

  describe '#analyze' do
    before { analyzer.analyze }

    it 'parses input elements (excluding hidden)' do
      inputs = analyzer.elements.select { |e| e[:type] == :input }
      expect(inputs.length).to eq(2)
      names = inputs.map { |e| e[:name] }
      expect(names).to include('username', 'password')
    end

    it 'parses select elements' do
      selects = analyzer.elements.select { |e| e[:type] == :select }
      expect(selects.length).to eq(1)
      expect(selects.first[:name]).to eq('role')
    end

    it 'parses textarea elements' do
      textareas = analyzer.elements.select { |e| e[:type] == :textarea }
      expect(textareas.length).to eq(1)
    end

    it 'parses button elements' do
      buttons = analyzer.elements.select { |e| e[:type] == :button }
      expect(buttons.length).to eq(1)
      expect(buttons.first[:text]).to eq('Log In')
    end

    it 'parses submit inputs' do
      submits = analyzer.elements.select { |e| e[:type] == :submit }
      expect(submits.length).to eq(1)
    end

    it 'parses link elements' do
      links = analyzer.elements.select { |e| e[:type] == :link }
      expect(links.length).to eq(1)
      expect(links.first[:name]).to eq('forgot_password')
    end

    it 'prefers id locators' do
      username = analyzer.elements.find { |e| e[:name] == 'username' }
      expect(username[:locator]).to eq(type: :id, value: 'username')
    end
  end

  describe '#page_name' do
    it 'derives name from URL path' do
      expect(analyzer.page_name).to eq('login')
    end

    it 'uses name override when provided' do
      custom = described_class.new('https://example.com/login', name_override: 'auth')
      expect(custom.page_name).to eq('auth')
    end

    it 'defaults to home for root URL' do
      root = described_class.new('https://example.com/')
      expect(root.page_name).to eq('home')
    end
  end

  describe '#to_h' do
    it 'returns structured hash' do
      analyzer.analyze
      result = analyzer.to_h
      expect(result).to include(:page_name, :url, :url_path, :elements)
      expect(result[:url_path]).to eq('/login')
    end
  end

  describe 'AI mode' do
    let(:ai_analyzer) { described_class.new('https://example.com/login', ai: true) }

    it 'falls back to regex parsing when LLM is unavailable' do
      allow_any_instance_of(described_class).to receive(:analyze_with_llm).and_return(nil)
      ai_analyzer.analyze
      expect(ai_analyzer.elements).not_to be_empty
    end
  end
end
