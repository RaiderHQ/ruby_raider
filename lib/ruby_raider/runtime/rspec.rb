# frozen_string_literal: true

require 'rspec/expectations'
require_relative '../runtime'
require_relative 'matchers/base'
require_relative 'matchers/element'

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
  end
  # rubocop:enable Naming/PredicatePrefix
end
