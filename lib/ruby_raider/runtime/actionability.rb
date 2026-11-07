# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'
require_relative 'errors'
require_relative 'wait'
require_relative 'context'

module Raider
  # Waits for an element to be actionable before an action runs. The checks run
  # in the browser (js/actionability.js); this module owns the action table and
  # the poll loop.
  module Actionability
    CHECKS = {
      click: %w[visible enabled inert stable events],
      send_keys: %w[visible enabled editable inert],
      clear: %w[visible enabled editable inert],
      submit: %w[visible enabled inert]
    }.freeze

    PHRASES = {
      'visible' => 'be visible',
      'enabled' => 'be enabled',
      'editable' => 'be editable',
      'inert' => 'not be inert',
      'stable' => 'be stable',
      'events' => 'receive events'
    }.freeze

    SCRIPT = File.read(File.join(__dir__, 'js', 'actionability.js')).freeze
    NOTICE = '[raider] actionability on (Raider.actionability = false or force: true to skip)'

    class << self
      def ensure(element, action, force:)
        return unless Raider.actionability

        announce
        return attached(element) if force
        return unless Context.web_for?(element)

        wait(element, action)
      end

      def check(element, action)
        element.instance_variable_get(:@bridge).execute_script(SCRIPT, element, CHECKS.fetch(action))
      end

      def reset_notice
        @announced = false
      end

      private

      # force skips every check but attached: a stale element raises here.
      def attached(element)
        element.tag_name
        nil
      end

      def wait(element, action)
        last = nil
        Wait.until(timeout: Raider.timeout) do
          last = check(element, action)
          throw :not_ready, last['check'] if last
          true
        end
        nil
      rescue TimeoutError
        raise not_actionable(element, last)
      end

      def not_actionable(element, last)
        check = last.fetch('check')
        NotActionable.new(Describe.element(element), PHRASES.fetch(check, check), covering: covering(last))
      end

      def covering(last)
        found = last['covering']
        found&.transform_keys(&:to_sym)
      end

      def announce
        return if @announced || ENV['RAIDER_QUIET'] == '1'

        @announced = true
        $stderr.puts NOTICE # rubocop:disable Style/StderrPuts -- the notice must not be silenced by -W0
      end
    end
  end
end
