# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'runtime/config'
require_relative 'runtime/errors'
require_relative 'runtime/wait'
require_relative 'runtime/context'
require_relative 'runtime/selectors'
require_relative 'runtime/locator_converter'
require_relative 'runtime/finders'

Raider::Finders.install
Raider::Finders.guard
