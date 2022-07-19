# frozen_string_literal: true

require_relative 'scaffolding_commands'
require_relative 'utility_commands'

module CommandLoader
  ScaffoldingCommands.start
  UtilityCommands.start
end
