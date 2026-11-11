# frozen_string_literal: true

require 'rbconfig'
require_relative 'base'
require_relative 'os/command_runner'
require_relative 'os/launchd'
require_relative 'os/task_scheduler'
require_relative 'os/linux'

module RubyRaider
  module Schedules
    # The OS scheduler for this machine, for schedules of the kind; only Linux asks the system (is the user's systemd there?)
    def self.adapter(kind:, runner: Os::CommandRunner.new, host_os: RbConfig::CONFIG['host_os'])
      case host_os
      when /darwin/ then Os::Launchd.new(kind: kind, runner: runner)
      when /mswin|mingw|cygwin/ then Os::TaskScheduler.new(kind: kind, runner: runner)
      when /linux/ then Os::Linux.pick(runner, kind: kind)
      else raise Error, kind.unsupported(host_os)
      end
    end
  end
end
