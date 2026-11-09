# frozen_string_literal: true

require 'rbconfig'
require_relative '../../../../lib/utilities/flows/os/command_runner'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::Os::CommandRunner do # rubocop:disable RSpec/FilePath
  let(:runner) { described_class.new }
  let(:ruby) { RbConfig.ruby }

  it 'captures stdout, stderr and the exit status' do
    result = runner.call(ruby, '-e', '$stdout.print "out"; $stderr.print "err"; exit 3')

    expect([result.stdout, result.stderr, result.exitstatus, result.success?]).to eq(['out', 'err', 3, false])
  end

  it 'succeeds on exit 0' do
    expect(runner.call(ruby, '-e', 'exit 0').success?).to be(true)
  end

  it 'feeds stdin' do
    expect(runner.call(ruby, '-e', 'print $stdin.read.upcase', stdin_data: "a b\n").stdout).to eq("A B\n")
  end

  it 'adds env values to the command environment' do
    result = runner.call(ruby, '-e', 'print ENV["RAIDER_NOTIFY_TITLE"]', env: { 'RAIDER_NOTIFY_TITLE' => '$(id)' })

    expect(result.stdout).to eq('$(id)')
  end

  it 'passes arguments without a shell' do
    hostile = ["'; rm -rf ~; '", '$(id)', '%h', '</string>']

    expect(runner.call(ruby, '-e', 'print ARGV.join("|")', *hostile).stdout).to eq(hostile.join('|'))
  end

  it 'never runs a single string through a shell' do
    result = runner.call('echo $(id)')

    expect([result.success?, result.stdout]).to eq([false, ''])
  end

  it 'returns a failed result for a missing executable' do
    result = runner.call('/no/such/raider-command', 'x')

    expect([result.success?, result.exitstatus, result.stderr]).to match([false, 127, /raider-command/])
  end
end
