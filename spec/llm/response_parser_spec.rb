# frozen_string_literal: true

require_relative '../../lib/llm/response_parser'

RSpec.describe Llm::ResponseParser do
  describe '.parse_json' do
    it 'parses raw JSON' do
      result = described_class.parse_json('{"key": "value"}')
      expect(result).to eq(key: 'value')
    end

    it 'parses JSON from markdown code block' do
      response = "```json\n{\"key\": \"value\"}\n```"
      result = described_class.parse_json(response)
      expect(result).to eq(key: 'value')
    end

    it 'extracts JSON from surrounding text' do
      response = "Here is the result:\n{\"key\": \"value\"}\nDone."
      result = described_class.parse_json(response)
      expect(result).to eq(key: 'value')
    end

    it 'returns nil for nil input' do
      expect(described_class.parse_json(nil)).to be_nil
    end

    it 'returns nil for empty input' do
      expect(described_class.parse_json('')).to be_nil
    end

    it 'returns nil for invalid JSON' do
      expect(described_class.parse_json('not json at all')).to be_nil
    end

    it 'returns nil for JSON arrays (not hashes)' do
      expect(described_class.parse_json('[1, 2, 3]')).to be_nil
    end
  end

  describe '.extract_elements' do
    let(:valid_response) do
      {
        elements: [
          { name: 'email_field', type: 'input', locator: { type: 'id', value: 'email' }, purpose: 'Email input' },
          { name: 'submit_btn', type: 'button', locator: { type: 'id', value: 'submit' }, text: 'Submit' }
        ]
      }.to_json
    end

    it 'extracts and normalizes elements' do
      elements = described_class.extract_elements(valid_response)
      expect(elements.length).to eq(2)
      expect(elements.first[:name]).to eq('email_field')
      expect(elements.first[:locator][:type]).to eq(:id)
    end

    it 'skips elements without required fields' do
      response = { elements: [{ name: 'incomplete' }] }.to_json
      elements = described_class.extract_elements(response)
      expect(elements).to be_empty
    end

    it 'returns nil for non-element response' do
      expect(described_class.extract_elements('{"other": "data"}')).to be_nil
    end

    it 'returns nil for nil response' do
      expect(described_class.extract_elements(nil)).to be_nil
    end
  end

  describe '.extract_scenarios' do
    let(:valid_response) do
      {
        scenarios: [
          { method: 'login', description: 'logs in with valid credentials', assertion_hint: 'expect redirect' }
        ]
      }.to_json
    end

    it 'extracts scenarios' do
      scenarios = described_class.extract_scenarios(valid_response)
      expect(scenarios.length).to eq(1)
      expect(scenarios.first[:method]).to eq('login')
    end

    it 'returns nil for non-scenario response' do
      expect(described_class.extract_scenarios('{"other": "data"}')).to be_nil
    end
  end
end
