# frozen_string_literal: true

require 'rbconfig'
require_relative 'base'
require_relative 'os/command_runner'

module RubyRaider
  module Schedules
    # A desktop notification for a scheduled run with --notify. The title and message only ever travel as argv
    # items after `--` (osascript, notify-send: so a title like -e is not read as an option or a script) or as
    # environment values (PowerShell), so a hostile schedule name or test title can't run as AppleScript or PowerShell. Never raises: a notification
    # that can't be shown must not change how the run ends.
    # :reek:TooManyConstants { max_constants: 7 } -- the fixed command of each OS, the message cap and the timeout
    # :reek:TooManyInstanceVariables { max_instance_variables: 5 } -- the injected runner, OS, stream and PowerShell path, and the warned flag
    class Notifier
      MAX = 200
      TIMEOUT = 15
      OSASCRIPT = ['/usr/bin/osascript', '-e', 'on run argv', '-e',
                   'display notification (item 2 of argv) with title (item 1 of argv)', '-e', 'end run', '--'].freeze
      NOTIFY_SEND = ['notify-send', '--app-name=Ruby Raider', '--'].freeze
      MARKUP = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;' }.freeze
      # Reads the text from the environment and sets it as XML text nodes; one line with no double quotes, so
      # Windows command-line quoting can't split it. Shown under PowerShell's own app id, which Windows accepts.
      TOAST_SCRIPT = [
        "$ErrorActionPreference = 'Stop'",
        '$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]',
        '$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)',
        "$texts = $xml.GetElementsByTagName('text')",
        '$null = $texts.Item(0).AppendChild($xml.CreateTextNode($env:RAIDER_NOTIFY_TITLE))',
        '$null = $texts.Item(1).AppendChild($xml.CreateTextNode($env:RAIDER_NOTIFY_MESSAGE))',
        '$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)',
        "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe').Show($toast)"
      ].join('; ').freeze
      POWERSHELL_ARGS = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', TOAST_SCRIPT].freeze

      def self.powershell = File.join(ENV.fetch('SystemRoot', 'C:\\Windows'), 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe')

      def initialize(runner: Os::CommandRunner.new, host_os: RbConfig::CONFIG['host_os'], err: $stderr, powershell: Notifier.powershell)
        @runner = runner
        @host_os = host_os
        @err = err
        @powershell = powershell
        @warned = false
      end

      # True when the notification was handed to the desktop
      def notify(title, message)
        title = clean(title)
        message = clean(message)
        result = case @host_os
                 when /darwin/ then @runner.call(*OSASCRIPT, title, message, timeout: TIMEOUT)
                 when /linux/ then @runner.call(*NOTIFY_SEND, title, message.gsub(/[&<>]/, MARKUP), timeout: TIMEOUT)
                 when /mswin|mingw|cygwin/
                   @runner.call(@powershell, *POWERSHELL_ARGS, env: { 'RAIDER_NOTIFY_TITLE' => title, 'RAIDER_NOTIFY_MESSAGE' => message },
                                                               timeout: TIMEOUT)
                 end
        return false unless result
        return true if result.success?

        failed(result.stderr)
      rescue StandardError => e
        failed(e.message)
      end

      private

      def clean(text) = Schedules.printable(text)[0, MAX].to_s

      def failed(reason)
        @err.puts("Could not show a desktop notification: #{Schedules.printable(reason.strip)}") unless @warned
        @warned = true
        false
      end
    end
  end
end
