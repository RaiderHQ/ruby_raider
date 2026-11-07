# frozen_string_literal: true

require_relative 'base'
require_relative '../strict'

module Raider
  module Matchers
    # Matchers about whether elements exist under a driver or element.
    module Presence
      # The locator matches at least one element (negated: none). `expected` is the locator.
      class HaveElement < Base
        def verb
          'have element'
        end

        # Base#settled? already reads under Wait.immediately.
        def read(subject)
          subject.find_elements(expected)
        end

        def pass?(value)
          !value.empty?
        end

        def description
          "#{verb} #{Raider::Locator.describe([expected])}"
        end

        private

        def target
          polled_actual.is_a?(Selenium::WebDriver::Element) ? super : 'the page'
        end

        def show(value)
          value.size
        end
      end
    end
  end
end
