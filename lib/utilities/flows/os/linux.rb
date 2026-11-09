# frozen_string_literal: true

require_relative 'command_runner'
require_relative 'systemd'
require_relative 'cron'

module RubyRaider
  module Flows
    module Os
      # Linux: systemd user timers when the user's systemd manager answers, cron otherwise
      module Linux
        def self.pick(runner = CommandRunner.new)
          return Systemd.new(runner: runner) if runner.call(Systemd::SYSTEMCTL, '--user', 'show-environment').success?

          Cron.new(runner: runner)
        end
      end
    end
  end
end
