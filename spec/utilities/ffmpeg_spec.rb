# frozen_string_literal: true

require 'tmpdir'
require 'digest'
require 'fileutils'
require 'ruby_raider/ffmpeg'

describe RubyRaider::Ffmpeg do # rubocop:disable RSpec/FilePath, RSpec/MultipleMemoizedHelpers
  let(:bytes) { "#!/bin/sh\n" }
  let(:digest) { Digest::SHA256.hexdigest(bytes) }
  let(:cache) { Dir.mktmpdir('raider-ffmpeg-cache') }
  let(:env) { { 'RAIDER_CACHE_DIR' => cache } }
  let(:platform) { described_class.platform }
  let(:manifest) do
    { version: '9.9',
      assets: described_class::MANIFEST[:assets].keys.to_h { |p| [p, { url: "https://example.test/#{p}", sha256: digest }] } }
  end
  let(:calls) { [] }
  let(:warnings) { [] }
  let(:warner) { ->(msg) { warnings << msg } }
  let(:fetch) do
    lambda do |url, dest|
      calls << url
      File.binwrite(dest, bytes)
    end
  end
  let(:binary_name) { platform.to_s.start_with?('windows') ? 'ffmpeg.exe' : 'ffmpeg' }
  let(:cached_path) { File.join(cache, 'ffmpeg', '9.9', binary_name) }

  after { FileUtils.rm_rf(cache) }

  it 'maps host os/cpu to the four platforms and nil otherwise' do
    expect(described_class.platform(host_os: 'darwin23', host_cpu: 'arm64')).to eq('darwin-arm64')
    expect(described_class.platform(host_os: 'darwin23', host_cpu: 'x86_64')).to eq('darwin-x64')
    expect(described_class.platform(host_os: 'linux-gnu', host_cpu: 'x86_64')).to eq('linux-x64')
    expect(described_class.platform(host_os: 'mingw32', host_cpu: 'x64')).to eq('windows-x64')
    expect(described_class.platform(host_os: 'linux-gnu', host_cpu: 'aarch64')).to be_nil
  end

  it 'ships a placeholder manifest with https urls and nil checksums for all four platforms' do
    assets = described_class::MANIFEST[:assets]
    expect(assets.keys).to contain_exactly('darwin-arm64', 'darwin-x64', 'linux-x64', 'windows-x64')
    expect(assets.values.map { |a| a[:url] }).to all(start_with('https://'))
    expect(assets.values.map { |a| a[:sha256] }).to all(be_nil)
  end

  it 'derives the cache dir from RAIDER_CACHE_DIR or the home cache' do
    expect(described_class.cache_dir(env:)).to eq(cache)
    expect(described_class.cache_dir(env: {})).to end_with(File.join('raider')) if platform != 'windows-x64'
  end

  it 'prefers RAIDER_FFMPEG_PATH and never downloads then' do
    override = File.join(cache, 'my-ffmpeg')
    File.write(override, bytes)
    File.chmod(0o755, override)
    result = described_class.ensure!(env: env.merge('RAIDER_FFMPEG_PATH' => override), manifest:,
                                     fetch:, warn: warner)
    expect(result).to eq(override)
    expect(calls).to be_empty
    expect(warnings).to be_empty
  end

  it 'ignores ffmpeg on PATH when no override is set' do
    bin = Dir.mktmpdir('raider-path')
    File.write(File.join(bin, 'ffmpeg'), bytes)
    File.chmod(0o755, File.join(bin, 'ffmpeg'))
    expect(described_class.resolve(env: env.merge('PATH' => bin), manifest:)).to be_nil
  ensure
    FileUtils.rm_rf(bin)
  end

  it 'downloads once, verifies, caches at <cache>/ffmpeg/<version>/ffmpeg, chmods +x' do # rubocop:disable RSpec/MultipleExpectations
    result = described_class.ensure!(env:, manifest:, fetch:, warn: warner)
    expect(result).to eq(cached_path)
    expect(File.binread(result)).to eq(bytes)
    expect(File.executable?(result)).to be(true)
    expect(calls.size).to eq(1)
    expect(warnings).to be_empty
    expect(Dir.children(File.dirname(result))).to eq([binary_name])
  end

  it 'makes no fetch call on a second ensure!' do
    described_class.ensure!(env:, manifest:, fetch:, warn: warner)
    again = described_class.ensure!(env:, manifest:, fetch:, warn: warner)
    expect(again).to eq(cached_path)
    expect(calls.size).to eq(1)
  end

  it 'deletes the file and returns nil with one warning on a checksum mismatch' do
    bad = manifest.merge(assets: manifest[:assets].transform_values { |a| a.merge(sha256: 'a' * 64) })
    result = described_class.ensure!(env:, manifest: bad, fetch:, warn: warner)
    expect(result).to be_nil
    expect(warnings.size).to eq(1)
    expect(warnings.first).to match(/checksum/i)
    expect(Dir.glob(File.join(cache, 'ffmpeg', '**', '*')).select { |f| File.file?(f) }).to be_empty
  end

  it 'returns nil with "ffmpeg build not published yet" when the manifest sha256 is nil' do
    unpublished = manifest.merge(assets: manifest[:assets].transform_values { |a| a.merge(sha256: nil) })
    result = described_class.ensure!(env:, manifest: unpublished, fetch:, warn: warner)
    expect(result).to be_nil
    expect(warnings).to eq(['ffmpeg build not published yet'])
    expect(calls).to be_empty
  end

  it 'returns nil with one warning when fetch raises' do
    boom = ->(_url, _dest) { raise IOError, 'network down' }
    result = described_class.ensure!(env:, manifest:, fetch: boom, warn: warner)
    expect(result).to be_nil
    expect(warnings.size).to eq(1)
    expect(warnings.first).to include('network down')
  end

  it 'rejects non-https manifest urls without fetching' do
    http = manifest.merge(assets: manifest[:assets].transform_values { |a| a.merge(url: 'http://example.test/x') })
    result = described_class.ensure!(env:, manifest: http, fetch:, warn: warner)
    expect(result).to be_nil
    expect(warnings.size).to eq(1)
    expect(calls).to be_empty
  end

  it 'leaves exactly one valid binary when 4 threads call ensure! concurrently' do
    results = Array.new(4) do
      Thread.new { described_class.ensure!(env:, manifest:, fetch:, warn: warner) }
    end.map(&:value)
    expect(results).to all(eq(cached_path))
    expect(Dir.children(File.dirname(cached_path))).to eq([binary_name])
    expect(Digest::SHA256.file(cached_path).hexdigest).to eq(digest)
    expect(warnings).to be_empty
  end
end
