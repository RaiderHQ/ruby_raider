# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime/errors'

RSpec.describe 'Raider runtime errors' do
  after { Raider.reset }

  def fake(tag: 'button', id: nil, klass: nil, text: '')
    instance_double(Selenium::WebDriver::Element, tag_name: tag, text: text).tap do |element|
      allow(element).to receive(:attribute).with('id').and_return(id)
      allow(element).to receive(:attribute).with('class').and_return(klass)
    end
  end

  describe 'ancestry' do
    it 'subclasses the Selenium errors' do
      expect(Raider::Error.ancestors).to include(StandardError)
      expect(Raider::AmbiguousMatch.ancestors).to include(Selenium::WebDriver::Error::WebDriverError)
      expect(Raider::NotActionable.ancestors).to include(Selenium::WebDriver::Error::ElementNotInteractableError)
      expect(Raider::NotSupported.ancestors).to include(Selenium::WebDriver::Error::UnsupportedOperationError)
      expect(Raider::TimeoutError.ancestors).to include(Selenium::WebDriver::Error::TimeoutError)
    end
  end

  describe Raider::AmbiguousMatch do
    it 'describes the first three elements and counts the rest' do
      elements = [fake(id: 'save', text: 'Save'), fake(klass: 'toolbar'), fake, fake]
      error = described_class.new("by_role('button', name: 'Save')", elements)
      expect(error.message).to eq(
        "`by_role('button', name: 'Save')` matched 4 elements: `<button id=\"save\">Save</button>`, " \
        '`<button class="toolbar">`, `<button>` (+1 more); use find_elements, or narrow the locator'
      )
      expect(error.elements).to eq(elements)
    end

    it 'shows +0 more with three or fewer' do
      error = described_class.new('x', [fake, fake])
      expect(error.message).to eq('`x` matched 2 elements: `<button>`, `<button>` (+0 more); ' \
                                  'use find_elements, or narrow the locator')
    end
  end

  describe Raider::NotActionable do
    it 'reports the check and the covering element' do
      covering = { element: '<div class="overlay">', x: 412, y: 300 }
      error = described_class.new('<button id="save">', 'receive events', covering: covering)
      expect(error.message).to eq('waited 10s for `<button id="save">` to receive events; ' \
                                  '`<div class="overlay">` covers it at (412, 300)')
      expect(error.check).to eq('receive events')
      expect(error.covering).to eq(covering)
    end

    it 'omits the covering clause' do
      error = described_class.new('<input id="q">', 'be visible')
      expect(error.message).to eq('waited 10s for `<input id="q">` to be visible')
    end

    it 'reports the waited seconds when given' do
      expect(described_class.new('<a>', 'be visible', waited: 0.25).message).to start_with('waited 0.25s for')
    end

    it 'formats fractional timeouts' do
      Raider.timeout = 2.5
      expect(described_class.new('<a>', 'be visible').message).to start_with('waited 2.5s for')
    end
  end

  describe Raider::Describe do
    it 'formats seconds' do
      expect([10, 2.5, 10.0, 2.504].map { |value| described_class.seconds(value) }).to eq([10, 2.5, 10, 2.5])
    end

    it 'limits classes to two and truncates text to 30 characters' do
      element = fake(klass: 'a b c', text: "  #{'x' * 40}  ")
      expect(described_class.element(element)).to eq("<button class=\"a b\">#{'x' * 30}</button>")
    end

    it 'skips empty id and class' do
      expect(described_class.element(fake(tag: 'div', id: '', klass: ' '))).to eq('<div>')
    end

    it 'returns <element> on a WebDriver error' do
      element = instance_double(Selenium::WebDriver::Element)
      allow(element).to receive(:tag_name).and_raise(Selenium::WebDriver::Error::StaleElementReferenceError)
      expect(described_class.element(element)).to eq('<element>')
    end
  end
end
