# frozen_string_literal: true

require 'forwardable'
require 'logger'

module RubyRaider
  module RaiderLog
    extend Forwardable
    def_delegators :level, :level=, :debug, :info, :warn, :error, :fatal

    DEFAULT_LOG_LEVEL = ::Logger::WARN

    private

    def logger
      @logger ||= ::Logger.new($stdout) do |log|
        log.level = @logger_level || DEFAULT_LOG_LEVEL
      end
    end
  end
end
