# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'stringio'
require_relative '../../lib/commands/utility_commands'

# rubocop:disable RSpec/FilePath
RSpec.describe UtilityCommands do
  let(:dir) { Dir.mktmpdir('raider-trace-project') }
  let(:config_path) { File.join(dir, 'config', 'config.yml') }

  around do |example|
    FileUtils.mkdir_p(File.join(dir, 'config'))
    File.write(config_path, "browser: chrome\ntimeout: 10\ntrace:\n  enabled: true\n  max_steps: 200\n  max_mb: 20\n")
    Dir.chdir(dir) { example.run }
  ensure
    FileUtils.rm_rf(dir)
  end

  def run_cli(*args)
    out = StringIO.new
    err = StringIO.new
    status = 0
    $stdout = out
    $stderr = err
    begin
      described_class.start(args)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = STDOUT
      $stderr = STDERR
    end
    [out.string, err.string, status]
  end

  describe 'trace on/off' do
    it 'round-trips trace.enabled, keeping the other trace keys and config keys' do
      out, _err, status = run_cli('trace', 'off')
      config = YAML.load_file(config_path)
      expect([status, out]).to match([0, /Trace capture disabled/])
      expect(config).to include('browser' => 'chrome', 'timeout' => 10, 'trace' => { 'enabled' => false, 'max_steps' => 200, 'max_mb' => 20 })

      out, = run_cli('trace', 'on')
      expect(out).to include('Trace capture enabled')
      expect(YAML.load_file(config_path)['trace']).to eq('enabled' => true, 'max_steps' => 200, 'max_mb' => 20)
    end

    it 'adds a trace block to a config that has none' do
      File.write(config_path, "browser: chrome\n")
      run_cli('trace', 'off')
      expect(YAML.load_file(config_path)['trace']).to eq('enabled' => false)
    end
  end

  describe 'trace with an unknown subcommand' do
    it 'exits 1 with usage' do
      _out, err, status = run_cli('trace', 'bogus')
      expect(status).to eq(1)
      expect(err).to include("Unknown trace command 'bogus'", 'on|off')
    end
  end
end
# rubocop:enable RSpec/FilePath
