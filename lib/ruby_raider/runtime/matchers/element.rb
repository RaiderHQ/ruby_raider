# frozen_string_literal: true

require_relative 'base'

module Raider
  module Matchers
    # Matchers that read one element. Readers go through read_with_zero_wait so a
    # template element (which takes timeout:) never waits inside the matcher's own wait.
    module Element
      # Collapses runs of whitespace so text compares the way it reads on the page.
      def self.normalise(text)
        text.to_s.strip.gsub(/\s+/, ' ')
      end

      # The text of an element, as a substring or (exact: true) as equality.
      class HaveText < Base
        def initialize(text, exact: false, wait: nil)
          super(text, wait: wait, exact: exact)
        end

        def verb
          option(:exact) ? 'have exact text' : 'have text'
        end

        def read(subject)
          read_with_zero_wait(subject, :text)
        end

        def pass?(value)
          actual = Element.normalise(value)
          return expected.match?(actual) if expected.is_a?(Regexp)

          wanted = Element.normalise(expected)
          option(:exact) ? actual == wanted : actual.include?(wanted)
        end
      end

      # The `value` attribute of a field.
      class HaveValue < Base
        def verb
          'have value'
        end

        def read(subject)
          read_with_zero_wait(subject, :attribute, 'value')
        end

        def pass?(value)
          expected.is_a?(Regexp) ? expected.match?(value.to_s) : value.to_s == expected.to_s
        end
      end

      # An attribute that is present, equal to a String or matching a Regexp.
      class HaveAttribute < Base
        PRESENT = :present

        def initialize(name, value = PRESENT, wait: nil)
          super(name, wait: wait, value: value)
        end

        def verb
          'have attribute'
        end

        def description
          wanted = option(:value)
          wanted == PRESENT ? super : "#{verb} #{expected.inspect} #{wanted.inspect}"
        end

        def read(subject)
          read_with_zero_wait(subject, :attribute, expected)
        end

        def pass?(value)
          wanted = option(:value)
          return !value.nil? if wanted == PRESENT
          return false if value.nil?

          wanted.is_a?(Regexp) ? wanted.match?(value.to_s) : value.to_s == wanted.to_s
        end
      end

      # A boolean state of an element, worded by the two labels it can read as.
      class State < Base
        LABELS = %w[yes no].freeze

        def initialize(wait: nil)
          super(true, wait: wait)
        end

        def description
          verb
        end

        def pass?(value)
          value == true
        end

        private

        def show(value)
          value ? self.class::LABELS.first : self.class::LABELS.last
        end
      end

      # Displayed on the page.
      class BeVisible < State
        LABELS = %w[visible hidden].freeze

        def verb
          'be visible'
        end

        def read(subject)
          read_with_zero_wait(subject, :displayed?)
        end

        private

        # Gone counts as not visible for the negated form.
        def negated_absent_passes?
          true
        end
      end

      # Not displayed, or gone: absence is a pass for the positive form.
      class BeHidden < State
        LABELS = %w[hidden visible].freeze

        def verb
          'be hidden'
        end

        def absent_passes?
          true
        end

        def read(subject)
          !read_with_zero_wait(subject, :displayed?)
        end
      end

      # Enabled for interaction.
      class BeEnabled < State
        LABELS = %w[enabled disabled].freeze

        def verb
          'be enabled'
        end

        def read(subject)
          read_with_zero_wait(subject, :enabled?)
        end
      end

      # Not enabled.
      class BeDisabled < State
        LABELS = %w[disabled enabled].freeze

        def verb
          'be disabled'
        end

        def read(subject)
          !read_with_zero_wait(subject, :enabled?)
        end
      end

      # A checked checkbox or radio, or a selected option.
      class BeChecked < State
        LABELS = %w[checked unchecked].freeze

        def verb
          'be checked'
        end

        def read(subject)
          read_with_zero_wait(subject, :selected?)
        end
      end
    end
  end
end
