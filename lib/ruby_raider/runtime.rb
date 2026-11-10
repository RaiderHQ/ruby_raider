# frozen_string_literal: true

require 'selenium-webdriver'
require_relative 'runtime/config'
require_relative 'runtime/errors'
require_relative 'runtime/by_role'
require_relative 'runtime/wait'
require_relative 'runtime/context'
require_relative 'runtime/selectors'
require_relative 'runtime/locator_converter'
require_relative 'runtime/finders'
require_relative 'runtime/role_finder'
require_relative 'runtime/observer'
require_relative 'runtime/actionability'
require_relative 'runtime/strict'
require_relative 'runtime/actionable'
require_relative 'runtime/show_browser'

Raider::Finders.check_api
Raider::Finders.install
Raider::Finders.guard
Raider::ShowBrowser.install
