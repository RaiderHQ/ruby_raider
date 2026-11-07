# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'config'

module Raider
  # Formats elements and durations for error messages.
  module Describe
    TEXT_LIMIT = 30
    CLASS_LIMIT = 2

    module_function

    def seconds(value)
      rounded = value.round(2)
      rounded == rounded.to_i ? rounded.to_i : rounded
    end

    def element(element)
      tag = element.tag_name
      id = element.attribute('id').to_s
      classes = element.attribute('class').to_s.split.first(CLASS_LIMIT).join(' ')
      text = element.text.to_s.strip[0, TEXT_LIMIT]
      open = "<#{tag}#{attribute_part('id', id)}#{attribute_part('class', classes)}>"
      text.empty? ? open : "#{open}#{text}</#{tag}>"
    rescue Selenium::WebDriver::Error::WebDriverError
      '<element>'
    end

    def attribute_part(name, value)
      value.empty? ? '' : %( #{name}="#{value}")
    end
  end

  # A strict finder matched more than one element.
  class AmbiguousMatch < Selenium::WebDriver::Error::WebDriverError
    SHOWN = 3

    attr_reader :elements

    def initialize(locator_description, elements)
      @elements = elements
      listed = elements.first(SHOWN).map { |element| "`#{Describe.element(element)}`" }.join(', ')
      more = [elements.size - SHOWN, 0].max
      super("`#{locator_description}` matched #{elements.size} elements: #{listed} (+#{more} more); " \
            'use find_elements, or narrow the locator')
    end
  end

  # An element did not become actionable within the timeout.
  class NotActionable < Selenium::WebDriver::Error::ElementNotInteractableError
    attr_reader :check, :covering, :retries

    def initialize(element_description, check, covering: nil, waited: Raider.timeout, retries: 0)
      @check = check
      @retries = retries
      @covering = covering
      message = "waited #{Describe.seconds(waited)}s for `#{element_description}` to #{check}"
      message += "; `#{covering[:element]}` covers it at (#{covering[:x]}, #{covering[:y]})" if covering
      super(message)
    end
  end

  # The requested operation is not supported.
  class NotSupported < Selenium::WebDriver::Error::UnsupportedOperationError; end

  # A runtime wait timed out.
  class TimeoutError < Selenium::WebDriver::Error::TimeoutError; end
end
