# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'
require_relative 'errors'
require_relative 'wait'
require_relative 'context'

module Raider
  # Waits for an element to be actionable before an action runs. On web contexts
  # the checks run in the browser (js/actionability.js); on native ones the gate
  # polls displayed?/enabled?. This module owns the check tables and the poll loops.
  # :reek:TooManyConstants { max_constants: 6 } -- one table per check set, the script and the notice
  module Actionability
    CHECKS = {
      click: %w[visible enabled inert stable events],
      send_keys: %w[visible enabled editable inert],
      clear: %w[visible enabled editable inert],
      submit: %w[visible enabled inert]
    }.freeze

    NATIVE_CHECKS = {
      click: %w[visible enabled],
      send_keys: %w[visible enabled],
      clear: %w[visible enabled],
      submit: []
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
    FIRST_POLL = { 'check' => 'stable', 'first' => true }.freeze
    NOTICE = '[raider] actionability on (Raider.actionability = false or force: true to skip)'

    class << self
      # Returns the number of not-ready polls (0 when skipped or ready at once).
      def ensure(element, action, force:)
        return 0 unless Raider.actionability

        announce
        web = Context.web_for?(element)
        return attached(element, web) if force

        poll(element) { web ? polled(element, action) : native_failure(element, action) }
      end

      def check(element, action)
        element.instance_variable_get(:@bridge).execute_script(SCRIPT, element, CHECKS.fetch(action))
      end

      def reset_notice
        @announced = false
      end

      private

      # force skips every check but attached: a stale element raises here.
      def attached(element, web)
        web ? element.tag_name : element.displayed?
        0
      end

      # Counts the polls whose block returns a failing check; the last one names the timeout.
      def poll(element)
        last = nil
        retries = 0
        started = clock
        Wait.until(timeout: Raider.timeout) do
          last = yield
          next true unless last

          retries += 1
          throw :not_ready, last['check']
        end
        retries
      rescue TimeoutError
        raise not_actionable(element, last, clock - started)
      end

      # Plain Appium commands, no script: the first check that fails, else nil.
      def native_failure(element, action)
        failing = NATIVE_CHECKS.fetch(action).find { |name| !native_ready?(element, name) }
        failing && { 'check' => failing }
      end

      # The first poll only stores a rect for stable to compare with, so a short pause
      # (inside the block; Wait.until's interval is fixed) replaces the full poll interval.
      def polled(element, action)
        result = check(element, action)
        return result unless result == FIRST_POLL

        sleep 0.02
        check(element, action)
      end

      def native_ready?(element, name)
        name == 'visible' ? element.displayed? : element.enabled?
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def not_actionable(element, last, waited)
        check = last.fetch('check')
        NotActionable.new(Describe.element(element), PHRASES.fetch(check, check), covering: covering(last), waited: waited)
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
