# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'stringio'
require_relative '../../lib/commands/utility_commands'

# rubocop:disable RSpec/FilePath
RSpec.describe UtilityCommands do
  let(:cache) { Dir.mktmpdir('raider-video-cache') }
  let(:project) { Dir.mktmpdir('raider-video-project') }
  let(:config_path) { File.join(project, 'config', 'config.yml') }

  around do |example|
    saved = ENV.to_h.slice('RAIDER_CACHE_DIR', 'RAIDER_FFMPEG_PATH')
    ENV['RAIDER_CACHE_DIR'] = cache
    ENV.delete('RAIDER_FFMPEG_PATH')
    FileUtils.mkdir_p(File.join(project, 'config'))
    File.write(config_path, "browser: chrome\ntimeout: 10\n")
    Dir.chdir(project) { example.run }
  ensure
    saved.each { |k, v| ENV[k] = v }
    ENV.delete('RAIDER_CACHE_DIR') unless saved.key?('RAIDER_CACHE_DIR')
    FileUtils.rm_rf([cache, project])
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

  describe 'video install' do
    it 'exits 1 and explains when the build is not published yet' do
      out, err, status = run_cli('video', 'install')
      expect(status).to eq(1)
      expect(err).to include('[video]', 'ffmpeg build not published yet')
      expect(out).to eq('')
    end

    it 'prints the path and exits 0 when ensure! succeeds' do
      require 'ruby_raider/ffmpeg'
      allow(RubyRaider::Ffmpeg).to receive(:ensure!).and_return('/tmp/ffmpeg')
      out, _err, status = run_cli('video', 'install')
      expect(status).to eq(0)
      expect(out).to include('/tmp/ffmpeg')
    end
  end

  describe 'video status' do
    it 'reports not installed with an empty cache' do
      out, _err, status = run_cli('video', 'status')
      expect(status).to eq(0)
      expect(out.strip).to eq('ffmpeg 7.1: not installed')
    end

    it 'prints the resolved path without downloading' do
      script = File.join(cache, 'fake-ffmpeg')
      File.write(script, "#!/bin/sh\n")
      File.chmod(0o755, script)
      ENV['RAIDER_FFMPEG_PATH'] = script
      out, = run_cli('video', 'status')
      expect(out.strip).to eq("ffmpeg 7.1: #{script}")
    end
  end

  describe 'video on/off' do
    it 'round-trips video.enabled, keeping other keys' do
      run_cli('video', 'off')
      config = YAML.load_file(config_path)
      expect(config['video']).to eq('enabled' => false)
      expect(config).to include('browser' => 'chrome', 'timeout' => 10)

      run_cli('video', 'on')
      expect(YAML.load_file(config_path)['video']).to eq('enabled' => true)
    end

    it 'preserves other keys under video' do
      File.write(config_path, "video:\n  enabled: true\n  fps: 5\n")
      run_cli('video', 'off')
      expect(YAML.load_file(config_path)['video']).to eq('enabled' => false, 'fps' => 5)
    end
  end

  describe 'video with an unknown subcommand' do
    it 'exits 1 with usage' do
      _out, err, status = run_cli('video', 'bogus')
      expect(status).to eq(1)
      expect(err).to include('install|status|on|off')
    end
  end

  describe 'help timeout' do
    it 'does not list the stray config options' do
      out, = run_cli('help', 'timeout')
      expect(out).not_to include('--path')
      expect(out).not_to include('--delete')
    end
  end
end
# rubocop:enable RSpec/FilePath
