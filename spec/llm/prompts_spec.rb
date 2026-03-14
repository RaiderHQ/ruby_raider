# frozen_string_literal: true

require_relative '../../lib/llm/prompts'

RSpec.describe Llm::Prompts do
  describe '.analyze_page' do
    it 'includes URL and HTML in prompt' do
      prompt = described_class.analyze_page('<html>test</html>', 'https://example.com')
      expect(prompt).to include('https://example.com')
      expect(prompt).to include('<html>test</html>')
    end

    it 'truncates HTML at 8000 characters' do
      long_html = 'x' * 10_000
      prompt = described_class.analyze_page(long_html, 'https://example.com')
      expect(prompt.length).to be < 10_000
    end

    it 'requests JSON output' do
      prompt = described_class.analyze_page('<html></html>', 'https://example.com')
      expect(prompt).to include('JSON')
      expect(prompt).to include('elements')
    end
  end

  describe '.generate_test_scenarios' do
    let(:methods) { [{ name: 'login', params: %w[user pass] }, { name: 'logout', params: [] }] }

    it 'includes class and method info' do
      prompt = described_class.generate_test_scenarios('LoginPage', methods, 'selenium', 'rspec')
      expect(prompt).to include('LoginPage')
      expect(prompt).to include('login(user, pass)')
      expect(prompt).to include('logout')
    end

    it 'includes automation and framework context' do
      prompt = described_class.generate_test_scenarios('LoginPage', methods, 'selenium', 'rspec')
      expect(prompt).to include('selenium')
      expect(prompt).to include('rspec')
    end
  end

  describe '.system_prompt' do
    it 'returns a non-empty string' do
      expect(described_class.system_prompt).to be_a(String)
      expect(described_class.system_prompt).not_to be_empty
    end
  end
end
