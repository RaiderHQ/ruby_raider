# frozen_string_literal: true

require 'tmpdir'
require 'digest'
require 'fileutils'
require 'stringio'
require 'ruby_raider/ffmpeg'

# rubocop:disable RSpec/FilePath, RSpec/MultipleMemoizedHelpers
describe RubyRaider::Ffmpeg do
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

  before { described_class.send(:reset_verified_cache!) }

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

  it 'derives the cache dir from RAIDER_CACHE_DIR or the home cache', :aggregate_failures do
    expect(described_class.cache_dir(env:)).to eq(cache)
    expect(described_class.cache_dir(env: {}, platform: 'linux-x64')).to eq(File.join(Dir.home, '.cache', 'raider'))
  end

  it 'uses LOCALAPPDATA on windows', :aggregate_failures do
    local = { 'LOCALAPPDATA' => '/Users/x/AppData/Local' }
    expect(described_class.cache_dir(env: local, platform: 'windows-x64')).to eq('/Users/x/AppData/Local/raider')
    expect(described_class.cached_path(env: local, manifest: described_class::MANIFEST, platform: 'windows-x64'))
      .to eq('/Users/x/AppData/Local/raider/ffmpeg/7.1/ffmpeg.exe')
  end

  it 'deep-freezes the manifest', :aggregate_failures do
    expect(described_class::MANIFEST).to be_frozen
    expect(described_class::MANIFEST[:assets]).to be_frozen
    expect(described_class::MANIFEST[:assets].values).to all(be_frozen)
    expect(described_class::MANIFEST[:assets].values.map { |a| a[:url] }).to all(be_frozen)
    expect(described_class::MANIFEST[:version]).to be_frozen
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

  it 'downloads once, verifies, caches at <cache>/ffmpeg/<version>/ffmpeg, chmods +x', :aggregate_failures do
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

  it 'warns once and falls through when RAIDER_FFMPEG_PATH is not an executable file' do
    bad = env.merge('RAIDER_FFMPEG_PATH' => File.join(cache, 'missing'))
    expect(described_class.resolve(env: bad, manifest:, warn: warner)).to be_nil
    expect(warnings).to eq(['RAIDER_FFMPEG_PATH is not an executable file; ignoring'])
  end

  describe 'cached binary verification' do
    before { FileUtils.mkdir_p(File.dirname(cached_path)) }

    it 'rejects a tampered cache: nil, one warning, no fetch, file removed', :aggregate_failures do
      File.write(cached_path, 'tampered')
      File.chmod(0o755, cached_path)
      result = described_class.ensure!(env:, manifest:, fetch:, warn: warner)
      expect(result).to be_nil
      expect(warnings).to eq(['cached ffmpeg failed checksum; video disabled'])
      expect(calls).to be_empty
      expect(File.exist?(cached_path)).to be(false)
    end

    it 'never trusts a cached file when the manifest sha256 is nil', :aggregate_failures do
      File.binwrite(cached_path, bytes)
      File.chmod(0o755, cached_path)
      unpublished = manifest.merge(assets: manifest[:assets].transform_values { |a| a.merge(sha256: nil) })
      result = described_class.ensure!(env:, manifest: unpublished, fetch:, warn: warner)
      expect(result).to be_nil
      expect(warnings).to eq(['ffmpeg build not published yet'])
      expect(calls).to be_empty
    end

    it 'does not rehash after a successful verification' do
      File.binwrite(cached_path, bytes)
      File.chmod(0o755, cached_path)
      described_class.ensure!(env:, manifest:, fetch:, warn: warner)
      allow(Digest::SHA256).to receive(:file).and_call_original
      described_class.ensure!(env:, manifest:, fetch:, warn: warner)
      expect(Digest::SHA256).not_to have_received(:file)
    end
  end

  describe 'never raising' do
    it 'warns once and returns nil when the cache dir cannot be created', :aggregate_failures do
      blocker = File.join(cache, 'blocker')
      File.write(blocker, 'x')
      result = described_class.ensure!(env: { 'RAIDER_CACHE_DIR' => blocker }, manifest:, fetch:, warn: warner)
      expect(result).to be_nil
      expect(warnings.size).to eq(1)
      expect(warnings.first).to match(/download failed/)
    end

    it 'warns once and returns nil when the home dir cannot be resolved', :aggregate_failures do
      allow(Dir).to receive(:home).and_raise(ArgumentError, 'couldn\'t find HOME')
      expect(described_class.ensure!(env: {}, manifest:, fetch:, warn: warner)).to be_nil
      expect(warnings.size).to eq(1)
      expect(warnings.first).to include("couldn't find HOME")
    end
  end

  it 'resolve never raises either', :aggregate_failures do
    allow(Dir).to receive(:home).and_raise(ArgumentError, "couldn't find HOME")
    expect(described_class.resolve(env: {}, manifest:, warn: warner, platform: 'linux-x64')).to be_nil
    expect(warnings.size).to eq(1)
    expect(warnings.first).to include("couldn't find HOME")
  end

  it 'reports the injected platform when no build exists for it' do
    described_class.ensure!(env:, manifest: { version: '9.9', assets: {} }, fetch:, warn: warner, platform: 'linux-x64')
    expect(warnings).to eq(['no ffmpeg build for this platform (linux-x64)'])
  end

  it 'rehashes a same-size replacement even when mtime is preserved' do
    FileUtils.mkdir_p(File.dirname(cached_path))
    File.binwrite(cached_path, bytes)
    File.chmod(0o755, cached_path)
    described_class.ensure!(env:, manifest:, fetch:, warn: warner)
    mtime = File.mtime(cached_path)
    File.delete(cached_path)
    File.binwrite(cached_path, 'X' * bytes.size)
    File.chmod(0o755, cached_path)
    File.utime(mtime, mtime, cached_path)
    expect(described_class.ensure!(env:, manifest:, fetch:, warn: warner)).to be_nil
    expect(warnings).to eq(['cached ffmpeg failed checksum; video disabled'])
  end

  describe 'DEFAULT_WARN' do
    it 'writes to $stderr even when $VERBOSE is nil' do
      original = $VERBOSE
      $VERBOSE = nil
      expect { described_class::DEFAULT_WARN.call('x') }.to output("[video] x\n").to_stderr
    ensure
      $VERBOSE = original
    end
  end

  describe '.obtainable?' do
    let(:unpublished) { manifest.merge(assets: manifest[:assets].transform_values { |a| a.merge(sha256: nil) }) }
    let(:override) do
      File.join(cache, 'my-ffmpeg').tap do |path|
        File.write(path, bytes)
        File.chmod(0o755, path)
      end
    end

    it 'is true when RAIDER_FFMPEG_PATH is an executable file, even with an unpublished manifest' do
      expect(described_class.obtainable?(env: { 'RAIDER_FFMPEG_PATH' => override }, manifest: unpublished)).to be(true)
    end

    it 'is true when the platform has a checksummed asset' do
      expect(described_class.obtainable?(env: {}, manifest:, platform: 'linux-x64')).to be(true)
    end

    it 'is false with no override and a nil checksum (the placeholder manifest)' do
      expect(described_class.obtainable?(env: {}, platform: 'darwin-arm64')).to be(false)
    end

    it 'is false for an unknown platform or a non-executable override' do
      File.chmod(0o644, override)
      expect(described_class.obtainable?(env: {}, manifest:, platform: 'plan9-mips')).to be(false)
      expect(described_class.obtainable?(env: { 'RAIDER_FFMPEG_PATH' => override }, manifest: unpublished)).to be(false)
    end

    it 'never fetches, hashes or warns' do
      allow(Digest::SHA256).to receive(:file)
      allow(Net::HTTP).to receive(:start)
      expect { described_class.obtainable?(env:, manifest:) }.not_to output.to_stderr
      expect(Digest::SHA256).not_to have_received(:file)
      expect(Net::HTTP).not_to have_received(:start)
    end

    it 'returns false instead of raising on a broken manifest' do
      expect(described_class.obtainable?(env: {}, manifest: { version: '1' }, platform: 'linux-x64')).to be(false)
    end
  end

  describe '.http_get' do
    let(:dest) { File.join(cache, 'download') }
    let(:http) { instance_double(Net::HTTP) }

    def response(klass, code, location: nil, body: nil)
      klass.new('1.1', code, 'x').tap do |res|
        res['location'] = location if location
        allow(res).to receive(:read_body).and_yield(body) if body
      end
    end

    def stub_responses(*responses)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request) { |_req, &blk| blk.call(responses.shift) }
    end

    it 'follows a redirect to https and writes the body', :aggregate_failures do
      stub_responses(response(Net::HTTPFound, '302', location: 'https://cdn.example.test/f'),
                     response(Net::HTTPOK, '200', body: 'payload'))
      described_class.http_get('https://example.test/f', dest)
      expect(File.read(dest)).to eq('payload')
      expect(Net::HTTP).to have_received(:start).with('cdn.example.test', 443, hash_including(use_ssl: true))
    end

    it 'raises on a redirect to http' do
      stub_responses(response(Net::HTTPFound, '302', location: 'http://evil.example.test/f'))
      expect { described_class.http_get('https://example.test/f', dest) }.to raise_error(ArgumentError, /non-https/)
    end

    it 'raises after more than 5 redirects' do
      stub_responses(*Array.new(7) { response(Net::HTTPFound, '302', location: 'https://example.test/f') })
      expect { described_class.http_get('https://example.test/f', dest) }.to raise_error(IOError, /too many redirects/)
    end

    it 'raises on a non-2xx response' do
      stub_responses(response(Net::HTTPNotFound, '404'))
      expect { described_class.http_get('https://example.test/f', dest) }.to raise_error(IOError, /404/)
    end

    it 'raises on a redirect without Location' do
      stub_responses(response(Net::HTTPFound, '302'))
      expect { described_class.http_get('https://example.test/f', dest) }.to raise_error(IOError, /Location/)
    end

    it 'does not nest connections when following redirects' do
      depth = 0
      max = 0
      allow(Net::HTTP).to receive(:start) do |*_args, &blk|
        depth += 1
        max = [max, depth].max
        blk.call(http)
      ensure
        depth -= 1
      end
      queue = [response(Net::HTTPFound, '302', location: 'https://example.test/g'),
               response(Net::HTTPOK, '200', body: 'x')]
      allow(http).to receive(:request) { |_req, &blk| blk.call(queue.shift) }
      described_class.http_get('https://example.test/f', dest)
      expect(max).to eq(1)
    end
  end

  it 'loads standalone without Thor' do
    root = File.expand_path('../..', __dir__)
    ok = system(RbConfig.ruby, "-I#{File.join(root, 'lib')}", '-e',
                'require "ruby_raider/ffmpeg"; exit(defined?(Thor) ? 1 : 0)')
    expect(ok).to be(true)
  end
end
# rubocop:enable RSpec/FilePath, RSpec/MultipleMemoizedHelpers
