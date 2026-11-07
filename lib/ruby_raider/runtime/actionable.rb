# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'observer'
require_relative 'actionability'

module Raider
  # Waits for actionability before each Element action. force: true skips the
  # checks except that the element must still be attached.
  module Actionable
    def click(force: false)
      Observer.emit_action(self, :click) do |run|
        raider_gate(run, :click, force)
        super()
      end
    end

    def send_keys(*keys, force: false)
      Observer.emit_action(self, :send_keys, keys) do |run|
        raider_gate(run, :send_keys, force)
        super(*keys)
      end
    end
    alias send_key send_keys

    def clear(force: false)
      Observer.emit_action(self, :clear) do |run|
        raider_gate(run, :clear, force)
        super()
      end
    end

    def submit(force: false)
      Observer.emit_action(self, :submit) do |run|
        raider_gate(run, :submit, force)
        super()
      end
    end

    private

    def raider_gate(run, action, force)
      retries = Actionability.ensure(self, action, force: force)
      run&.ready(retries)
    end
  end
end

Selenium::WebDriver::Element.prepend(Raider::Actionable)
