# frozen_string_literal: true

require 'rspec/expectations'
require_relative '../runtime'
require_relative 'matchers/base'
require_relative 'matchers/element'
require_relative 'matchers/page'
require_relative 'matchers/presence'
require_relative 'matchers/retrying_block'

module Raider
  # Web-first RSpec matchers that retry until the page settles.
  # rubocop:disable Naming/PredicatePrefix -- the matcher names are RSpec's vocabulary
  module Matchers
    def have_text(text, exact: false, wait: nil)
      Element::HaveText.new(text, exact: exact, wait: wait)
    end

    def have_value(value, wait: nil)
      Element::HaveValue.new(value, wait: wait)
    end

    def have_attribute(name, value = Element::HaveAttribute::PRESENT, wait: nil)
      Element::HaveAttribute.new(name, value, wait: wait)
    end

    def be_visible(wait: nil)
      Element::BeVisible.new(wait: wait)
    end

    def be_hidden(wait: nil)
      Element::BeHidden.new(wait: wait)
    end

    def be_enabled(wait: nil)
      Element::BeEnabled.new(wait: wait)
    end

    def be_disabled(wait: nil)
      Element::BeDisabled.new(wait: wait)
    end

    def be_checked(wait: nil)
      Element::BeChecked.new(wait: wait)
    end

    def have_element(locator = nil, wait: nil, **by)
      raise ArgumentError, 'have_element takes a locator, not both a hash and keywords' if locator && !by.empty?
      raise ArgumentError, 'have_element needs a locator' if locator.nil? && by.empty?

      Presence::HaveElement.new(locator || by, wait: wait)
    end

    def have_css(selector, wait: nil)
      have_element({ css: selector }, wait: wait)
    end

    def have_xpath(selector, wait: nil)
      have_element({ xpath: selector }, wait: wait)
    end

    def have_count(count, wait: nil)
      Page::HaveCount.new(count, wait: wait)
    end

    def have_title(expected, wait: nil)
      Page::HaveTitle.new(expected, wait: wait)
    end

    def have_url(expected, wait: nil)
      Page::HaveUrl.new(expected, wait: wait)
    end
  end
  # rubocop:enable Naming/PredicatePrefix
end

target = RSpec::Expectations::BlockExpectationTarget
target.prepend(Raider::Matchers::RetryingBlock) unless target.ancestors.include?(Raider::Matchers::RetryingBlock)
