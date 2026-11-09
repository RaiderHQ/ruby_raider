# frozen_string_literal: true

require 'stringio'
require_relative '../../../lib/utilities/flows/notifier'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::Notifier do # rubocop:disable RSpec/FilePath
  # Records each command instead of running it: no real osascript, notify-send or PowerShell
  let(:runner) do
    Class.new do
      attr_reader :calls
      attr_accessor :exitstatus

      def initialize
        @calls = []
        @exitstatus = 0
      end

      def call(*argv, env: {}, timeout: nil, **)
        @calls << { argv: argv, env: env, timeout: timeout }
        RubyRaider::Flows::Os::CommandRunner::Result.new(stdout: '', stderr: 'no notification server', exitstatus: exitstatus)
      end
    end.new
  end

  let(:err) { StringIO.new }
  let(:hostile) do
    ["'; rm -rf ~; '", '" & do shell script "id" & "', '$(id)', '</text>', '-u critical', '$env:USERPROFILE', '`whoami`']
  end

  let(:powershell) { 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe' }

  def notifier(host_os) = described_class.new(runner: runner, host_os: host_os, err: err, powershell: powershell)

  it 'passes the title and message to osascript as argv items of a fixed script on macOS' do
    expect(notifier('darwin25').notify('Ruby Raider flow report', 'Failed at step 3 (Open report)')).to be(true)

    expect(runner.calls).to eq([{ argv: ['/usr/bin/osascript', '-e', 'on run argv', '-e',
                                         'display notification (item 2 of argv) with title (item 1 of argv)', '-e', 'end run', '--',
                                         'Ruby Raider flow report', 'Failed at step 3 (Open report)'], env: {}, timeout: 15 }])
  end

  it 'ends osascript option parsing before the title, so -e in a title is not a script' do
    notifier('darwin25').notify('-e', 'property p : (1 + 2)')

    expect(runner.calls.first[:argv].last(3)).to eq(['--', '-e', 'property p : (1 + 2)'])
  end

  it 'keeps hostile text out of the script on every OS' do
    hosts = %w[darwin25 linux-gnu mingw32]
    scripts = hosts.to_h do |host|
      hostile.each { |text| notifier(host).notify(text, text) }
      calls = runner.calls.pop(hostile.size)
      [host, calls.map { |call| host == 'mingw32' ? call[:argv] : call[:argv][0...-2] }.uniq]
    end

    expect(scripts.values.map(&:size)).to eq([1, 1, 1])
    expect(scripts.values.flatten.join("\n")).not_to include(*hostile)
  end

  it 'passes hostile text unchanged as the last argv items on macOS' do
    hostile.each { |text| notifier('darwin25').notify(text, text) }

    expect(runner.calls.map { |call| call[:argv].last(2) }).to eq(hostile.map { |text| [text, text] })
  end

  it 'stops notify-send option parsing before the title and escapes markup in the message on Linux' do
    notifier('linux-gnu').notify('-u critical', 'a < b & c > d')

    expect(runner.calls.first[:argv]).to eq(['notify-send', '--app-name=Ruby Raider', '--', '-u critical', 'a &lt; b &amp; c &gt; d'])
  end

  it 'passes the title and message to a fixed PowerShell script through the environment on Windows' do
    notifier('mswin64').notify('$env:USERPROFILE', '`whoami`')

    expect(runner.calls.first).to eq(
      argv: [powershell, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', described_class::TOAST_SCRIPT],
      env: { 'RAIDER_NOTIFY_TITLE' => '$env:USERPROFILE', 'RAIDER_NOTIFY_MESSAGE' => '`whoami`' }, timeout: 15
    )
  end

  it 'finds PowerShell under SystemRoot by default' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SystemRoot', 'C:\\Windows').and_return('D:\\Win')
    described_class.new(runner: runner, host_os: 'mingw32', err: err).notify('t', 'm')

    expect(runner.calls.first[:argv].first).to eq(File.join('D:\\Win', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'))
  end

  it 'builds the toast from the environment, never from text joined into XML' do
    script = described_class::TOAST_SCRIPT

    expect(script).to include('$env:RAIDER_NOTIFY_TITLE', '$env:RAIDER_NOTIFY_MESSAGE', 'CreateTextNode', 'ToastText02')
    expect(script).not_to include('"', "\n", 'EncodedCommand')
  end

  it 'makes control characters printable and caps the message at 200 characters' do
    notifier('darwin25').notify("flow\e[2J", "#{'x' * 250}\n")

    expect(runner.calls.first[:argv].last(2)).to eq(['flow?[2J', 'x' * 200])
  end

  it 'does nothing on another OS' do
    expect([notifier('solaris2').notify('t', 'm'), runner.calls]).to eq([false, []])
  end

  it 'returns false and warns once when the notification fails, without raising' do
    runner.exitstatus = 1
    sender = notifier('linux-gnu')

    expect([sender.notify('t', 'm'), sender.notify('t', 'm')]).to eq([false, false])
    expect(err.string).to eq("Could not show a desktop notification: no notification server\n")
  end

  it 'returns false when the runner raises' do
    allow(runner).to receive(:call).and_raise(IOError, 'closed stream')

    expect(notifier('darwin25').notify('t', 'm')).to be(false)
    expect(err.string).to include('closed stream')
  end
end
