# frozen_string_literal: true

require_relative '../../../../lib/utilities/flows/os/linux'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::Os::Linux do # rubocop:disable RSpec/FilePath
  # Answers systemctl with the given exit status; never runs anything
  let(:fake_runner_class) do
    Class.new do
      attr_reader :calls

      def initialize(status)
        @status = status
        @calls = []
      end

      def call(*argv, stdin_data: nil)
        @calls << [*argv, stdin_data].compact
        RubyRaider::Flows::Os::CommandRunner::Result.new(stdout: '', stderr: '', exitstatus: @status)
      end
    end
  end

  it 'picks systemd when the user manager answers' do
    runner = fake_runner_class.new(0)

    expect(described_class.pick(runner)).to be_a(RubyRaider::Flows::Os::Systemd)
    expect(runner.calls).to eq([%w[systemctl --user show-environment]])
  end

  it 'falls back to cron when it does not, or systemctl is missing' do
    [1, RubyRaider::Flows::Os::CommandRunner::MISSING].each do |status|
      expect(described_class.pick(fake_runner_class.new(status))).to be_a(RubyRaider::Flows::Os::Cron)
    end
  end
end
