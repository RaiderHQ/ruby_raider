# frozen_string_literal: true

require_relative 'base'

module Raider
  module Matchers
    # Matchers about the page or a collection rather than one element.
    module Page
      # The size of an Array (read once) or of what a block returns (re-called each poll).
      class HaveCount < Base
        def verb
          'have count'
        end

        def read(subject)
          subject.size
        end

        def pass?(value)
          value == expected
        end

        private

        # A collection already in hand cannot change, so it gets a single pass.
        def wait_for(actual)
          actual.is_a?(Array) ? 0 : super
        end

        def target
          polled_actual.is_a?(Array) ? 'the array' : super
        end
      end

      # A value read from the driver: a String is equality, a Regexp is match?.
      class Driver < Base
        def pass?(value)
          expected.is_a?(Regexp) ? expected.match?(value.to_s) : value.to_s == expected.to_s
        end

        private

        def target
          'the page'
        end
      end

      # The title of the page.
      class HaveTitle < Driver
        def verb
          'have title'
        end

        def read(subject)
          subject.title
        end
      end

      # The current url of the page, whole: 'account' does not match '.../account'.
      class HaveUrl < Driver
        def verb
          'have url'
        end

        def read(subject)
          subject.current_url
        end
      end
    end
  end
end
