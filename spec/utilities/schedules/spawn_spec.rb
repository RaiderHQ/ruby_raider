# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/schedules/spawn'

RSpec.describe RubyRaider::Schedules::Spawn do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-spawn')) }
  let(:ready) { File.join(dir, 'ready') }
  let(:got) { File.join(dir, 'got') }
  # Counts the INTs it gets (TERM counts 100), then exits 0
  let(:child) do
    "n = 0; trap('INT') { n += 1 }; trap('TERM') { n += 100 }; File.write(#{ready.inspect}, ''); " \
      "sleep 1.5; File.write(#{got.inspect}, n.to_s)"
  end

  after { FileUtils.rm_rf(dir) }

  def signal_when_ready(*signals)
    Thread.new do
      sleep 0.05 until File.exist?(ready)
      signals.each { |signal| Process.kill(signal, Process.pid) }
    end
  end

  it 'runs without a shell and returns the exit status, not stopped' do
    result = described_class.call({ 'X' => '; exit 7' }, [RbConfig.ruby, '-e', 'exit(ENV["X"] == "; exit 7" ? 5 : 6)'], dir)

    expect(result).to eq([5, false])
  end

  it 'unsets a variable given as nil' do
    ENV['RAIDER_SPAWN_SPEC'] = 'inherited'
    result = described_class.call({ 'RAIDER_SPAWN_SPEC' => nil }, [RbConfig.ruby, '-e', 'exit(ENV.key?("RAIDER_SPAWN_SPEC") ? 1 : 0)'], dir)

    expect(result.first).to eq(0)
  ensure
    ENV.delete('RAIDER_SPAWN_SPEC')
  end

  describe 'stopping', skip: Gem.win_platform? do
    it 'passes TERM then INT on as one INT when the INT could not have reached the child' do
      signal_when_ready('TERM', 'INT')

      result = described_class.call({}, [RbConfig.ruby, '-e', child], dir, forward_int: true)

      expect([result, File.read(got)]).to eq([[0, true], '1'])
    end

    it 'does not pass on an INT that the terminal already sent to the child' do
      signal_when_ready('INT')

      result = described_class.call({}, [RbConfig.ruby, '-e', child], dir, forward_int: false)

      expect([result, File.read(got)]).to eq([[0, true], '0'])
    end

    it 'passes TERM on as one INT even when INTs are not forwarded' do
      signal_when_ready('TERM')

      result = described_class.call({}, [RbConfig.ruby, '-e', child], dir, forward_int: false)

      expect([result, File.read(got)]).to eq([[0, true], '1'])
    end

    it 'sends no second INT for a TERM after a terminal Ctrl-C' do
      signal_when_ready('INT', 'TERM')

      result = described_class.call({}, [RbConfig.ruby, '-e', child], dir, forward_int: false)

      expect([result, File.read(got)]).to eq([[0, true], '0'])
    end

    it 'passes on a stop that came before the child existed, once it does, whatever forward_int says' do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      state = { pid: nil, stopped: true, interrupted: false }

      code = described_class.run({}, [RbConfig.ruby, '-e', 'sleep 5'], dir, state, false)

      expect([code, state[:interrupted], Process.clock_gettime(Process::CLOCK_MONOTONIC) - started < 4]).to eq([nil, true, true])
    end

    it 'restores the previous handlers' do
      previous = trap('INT', 'IGNORE')
      described_class.call({}, [RbConfig.ruby, '-e', 'exit 0'], dir)

      expect(trap('INT', previous)).to eq('IGNORE')
    end
  end

  it 'returns no exit status with one line on stderr when the command is not found' do
    result = nil

    expect { result = described_class.call({}, ['raider-no-such-command'], dir) }.to output(/Could not start raider-no-such-command/).to_stderr
    expect(result).to eq([nil, false])
  end
end
