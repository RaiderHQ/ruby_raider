# frozen_string_literal: true

require 'thor'
require 'yaml'
require_relative 'commands/command_loader'

class RubyRaider < Thor
  include CommandLoader
end
