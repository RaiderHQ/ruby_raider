# frozen_string_literal: true

require 'rbconfig'
require_relative 'project'
require_relative 'os/command_runner'

module RubyRaider
  module Flows
    # A desktop notification for `raider flow run --notify`. The title and message only ever travel as argv
    # items (osascript, notify-send) or environment values (PowerShell), never as part of a script, so a
    # hostile flow name or step title can't run as AppleScript or PowerShell. Never raises: a notification
    # that can't be shown must not change how the run ends.
    # :reek:TooManyConstants { max_constants: 6 } -- the fixed command of each OS and the message cap
    class Notifier
      MAX = 200
      OSASCRIPT = ['/usr/bin/osascript', '-e', 'on run argv', '-e',
                   'display notification (item 2 of argv) with title (item 1 of argv)', '-e', 'end run'].freeze
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
      POWERSHELL = ['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', TOAST_SCRIPT].freeze

      def initialize(runner: Os::CommandRunner.new, host_os: RbConfig::CONFIG['host_os'], err: $stderr)
        @runner = runner
        @host_os = host_os
        @err = err
        @warned = false
      end

      # True when the notification was handed to the desktop
      def notify(title, message)
        title = clean(title)
        message = clean(message)
        result = case @host_os
                 when /darwin/ then @runner.call(*OSASCRIPT, title, message)
                 when /linux/ then @runner.call(*NOTIFY_SEND, title, message.gsub(/[&<>]/, MARKUP))
                 when /mswin|mingw|cygwin/
                   @runner.call(*POWERSHELL, env: { 'RAIDER_NOTIFY_TITLE' => title, 'RAIDER_NOTIFY_MESSAGE' => message })
                 end
        return false unless result
        return true if result.success?

        failed(result.stderr)
      rescue StandardError => e
        failed(e.message)
      end

      private

      def clean(text) = Flows.printable(text)[0, MAX].to_s

      def failed(reason)
        @err.puts("Could not show a desktop notification: #{Flows.printable(reason.strip)}") unless @warned
        @warned = true
        false
      end
    end
  end
end
