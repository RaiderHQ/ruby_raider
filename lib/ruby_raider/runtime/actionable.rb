# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'actionability'

module Raider
  # Waits for actionability before each Element action. force: true skips the
  # checks except that the element must still be attached.
  module Actionable
    def click(force: false)
      Actionability.ensure(self, :click, force: force)
      super()
    end

    def send_keys(*keys, force: false)
      Actionability.ensure(self, :send_keys, force: force)
      super(*keys)
    end
    alias send_key send_keys

    def clear(force: false)
      Actionability.ensure(self, :clear, force: force)
      super()
    end

    def submit(force: false)
      Actionability.ensure(self, :submit, force: force)
      super()
    end
  end
end

Selenium::WebDriver::Element.prepend(Raider::Actionable)
