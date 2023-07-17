require 'forwardable'
require 'logger'

module RubyRaider
  module Logger
    #
    # @example Use logger manually
    #   RubyRaider::Logger.debug('This is info message')
    #   RubyRaider::Logger.warn('This is warning message')
    #
    class << self
      extend Forwardable
      def_delegators :logger, :fatal, :error, :warn, :info, :debug, :level, :level=, :formatter, :formatter=

      def logger
        @logger ||= begin
          logger = ::Logger.new($stdout)
          logger.progname = 'ruby_raider'
          logger.level = ::Logger::WARN
          logger.formatter = proc { |_severity, _datetime, _progname, msg| "#{msg}\n" }
          logger
        end
      end
    end
  end
end
