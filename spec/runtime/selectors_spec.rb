# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/ruby_raider/runtime/selectors'

RSpec.describe 'Raider::Selectors' do
  let(:controls) do
    'self::input or self::textarea or self::select or self::button or ' \
      'self::meter or self::output or self::progress'
  end

  def label_xpath(match)
    [
      ".//*[@id = (.//label[#{match.call('.')}]/@for)]",
      ".//label[#{match.call('.')}]//*[#{controls}]",
      ".//*[#{match.call('@aria-label')}]",
      ".//*[@aria-labelledby and #{match.call('string(id(@aria-labelledby))')}]"
    ].join(' | ')
  end

  describe '.xpath_literal' do
    it 'single-quotes a value without single quotes' do
      expect(Raider::Selectors.xpath_literal('Sign in')).to eq("'Sign in'")
    end

    it 'double-quotes a value with only single quotes' do
      expect(Raider::Selectors.xpath_literal("O'Neil")).to eq(%q("O'Neil"))
    end

    it 'single-quotes a value with only double quotes' do
      expect(Raider::Selectors.xpath_literal('say "hi"')).to eq(%q('say "hi"'))
    end

    it 'uses concat when both quote kinds appear' do
      expect(Raider::Selectors.xpath_literal(%q(O'Neil "the" boss)))
        .to eq(%q(concat('O', "'", 'Neil "the" boss')))
    end

    it 'handles leading, trailing and repeated single quotes with concat' do
      expect(Raider::Selectors.xpath_literal(%q('a''"b')))
        .to eq(%q(concat('', "'", 'a', "'", '', "'", '"b', "'", '')))
    end

    it 'converts non-strings with to_s' do
      expect(Raider::Selectors.xpath_literal(42)).to eq("'42'")
    end
  end

  describe '.label' do
    it 'builds the contains union by default' do
      match = ->(x) { "contains(normalize-space(#{x}), 'Email')" }
      expect(Raider::Selectors.label('Email', exact: false)).to eq(label_xpath(match))
    end

    it 'builds the equality union with exact: true' do
      match = ->(x) { "normalize-space(#{x}) = 'Email'" }
      expect(Raider::Selectors.label('Email', exact: true)).to eq(label_xpath(match))
    end

    it 'does not let a quote break out of the literal' do
      xpath = Raider::Selectors.label("x'] | //*['", exact: false)
      expect(xpath).to include(%q("x'] | //*['"))
    end
  end

  describe '.text' do
    it 'builds the innermost-match xpath' do
      expect(Raider::Selectors.text('Sign in', exact: false)).to eq(
        ".//*[contains(normalize-space(.), 'Sign in') and " \
        "not(.//*[contains(normalize-space(.), 'Sign in')])]"
      )
    end

    it 'uses equality with exact: true' do
      expect(Raider::Selectors.text('Sign in', exact: true)).to eq(
        ".//*[normalize-space(.) = 'Sign in' and not(.//*[normalize-space(.) = 'Sign in'])]"
      )
    end

    it 'uses concat for a value with both quote kinds' do
      literal = %q(concat('O', "'", 'Neil "the" boss'))
      expect(Raider::Selectors.text(%q(O'Neil "the" boss), exact: false)).to eq(
        ".//*[contains(normalize-space(.), #{literal}) and " \
        "not(.//*[contains(normalize-space(.), #{literal})])]"
      )
    end

    it 'single-quotes a value with only double quotes' do
      expect(Raider::Selectors.text('say "hi"', exact: true)).to include(%q(= 'say "hi"'))
    end
  end

  describe '.attribute_css' do
    it 'escapes the inner quote for a contains match' do
      expect(Raider::Selectors.attribute_css('placeholder', 'a[b]"c', exact: false))
        .to eq('[placeholder*="a[b]\"c"]')
    end

    it 'uses equality when exact' do
      expect(Raider::Selectors.attribute_css('title', 'Hi', exact: true)).to eq('[title="Hi"]')
    end

    it 'escapes backslashes before quotes' do
      expect(Raider::Selectors.attribute_css('alt', 'a\\"b', exact: true))
        .to eq('[alt="a\\\\\\"b"]')
    end

    it 'rejects an invalid attribute name' do
      expect { Raider::Selectors.attribute_css('a]b', 'x', exact: true) }
        .to raise_error(ArgumentError, 'invalid attribute name: a]b')
    end
  end

  describe '.test_id' do
    after { Raider.reset }

    it 'uses the default attribute' do
      expect(Raider::Selectors.test_id('x')).to eq('[data-testid="x"]')
    end

    it 'uses a configured attribute' do
      Raider.test_id_attribute = 'data-qa'
      expect(Raider::Selectors.test_id('x')).to eq('[data-qa="x"]')
    end

    it 'rejects a configured attribute that is not a plain name' do
      Raider.test_id_attribute = 'data-qa]'
      expect { Raider::Selectors.test_id('x') }.to raise_error(ArgumentError, /invalid attribute name/)
    end
  end
end
