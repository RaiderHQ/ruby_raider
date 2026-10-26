# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'net/http'
require 'rbconfig'
require 'securerandom'
require 'uri'

module RubyRaider
  # Pinned, checksum-verified ffmpeg provisioning. Stdlib only so generated
  # projects can load it standalone via `require 'ruby_raider/ffmpeg'`.
  module Ffmpeg
    MAX_REDIRECTS = 5

    # Checksums are filled in when the RaiderHQ `ffmpeg-7.1` release is cut.
    RELEASE_BASE = 'https://github.com/RaiderHQ/ruby_raider/releases/download/ffmpeg-7.1/ffmpeg-7.1-'
    MANIFEST = {
      version: '7.1',
      assets: {
        'darwin-arm64' => { url: "#{RELEASE_BASE}darwin-arm64".freeze, sha256: nil }.freeze,
        'darwin-x64' => { url: "#{RELEASE_BASE}darwin-x64".freeze, sha256: nil }.freeze,
        'linux-x64' => { url: "#{RELEASE_BASE}linux-x64".freeze, sha256: nil }.freeze,
        'windows-x64' => { url: "#{RELEASE_BASE}windows-x64.exe".freeze, sha256: nil }.freeze
      }.freeze
    }.freeze

    PLATFORMS = %w[darwin-arm64 darwin-x64 linux-x64 windows-x64].freeze
    # $stderr.puts, not Kernel#warn: warn is silenced under -W0 / $VERBOSE = nil.
    # rubocop:disable Style/StderrPuts
    DEFAULT_WARN = ->(message) { $stderr.puts("[video] #{message}") }
    # rubocop:enable Style/StderrPuts

    @verified = {}

    class << self
      def platform(host_os: RbConfig::CONFIG['host_os'], host_cpu: RbConfig::CONFIG['host_cpu'])
        os = host_os_name(host_os)
        cpu = host_cpu_name(host_cpu)
        return nil unless os && cpu

        candidate = "#{os}-#{cpu}"
        PLATFORMS.include?(candidate) ? candidate : nil
      end

      def cache_dir(env: ENV, platform: self.platform)
        override = env['RAIDER_CACHE_DIR']
        return override if override && !override.empty?

        local = env['LOCALAPPDATA']
        if platform == 'windows-x64' && local && !local.empty?
          File.join(local, 'raider')
        else
          File.join(Dir.home, '.cache', 'raider')
        end
      end

      def cached_path(env: ENV, manifest: MANIFEST, platform: self.platform)
        name = platform.to_s.start_with?('windows') ? 'ffmpeg.exe' : 'ffmpeg'
        File.join(cache_dir(env:, platform:), 'ffmpeg', manifest[:version], name)
      end

      # No network: the env override if executable, else the verified cached binary.
      # Never raises: any StandardError becomes one warning and nil.
      def resolve(env: ENV, manifest: MANIFEST, warn: nil, platform: nil)
        warn ||= DEFAULT_WARN
        guarded(warn) do
          lookup(env, manifest, warn, platform || self.platform).first
        end
      end

      # Never raises: any StandardError becomes one warning and nil.
      def ensure!(env: ENV, manifest: MANIFEST, fetch: nil, warn: nil, platform: nil)
        warn ||= DEFAULT_WARN
        guarded(warn) do
          platform ||= self.platform
          path, final = lookup(env, manifest, warn, platform)
          next path if path || final

          provision(env, manifest, fetch || method(:http_get), warn, platform)
        end
      end

      def http_get(url, destination, limit = MAX_REDIRECTS)
        raise ArgumentError, "refusing non-https url: #{url}" unless https?(url)
        raise IOError, 'too many redirects' if limit.negative?

        uri = URI(url)
        location = nil
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
          http.request(Net::HTTP::Get.new(uri)) do |response|
            case response
            when Net::HTTPSuccess
              File.open(destination, 'wb') { |file| response.read_body { |chunk| file.write(chunk) } }
            when Net::HTTPRedirection
              location = response['location']
              raise IOError, 'redirect without Location header' unless location
            else
              raise IOError, "download failed: HTTP #{response.code}"
            end
          end
        end
        http_get(URI.join(url, location).to_s, destination, limit - 1) if location
      end

      private

      def guarded(warn)
        yield
      rescue StandardError => e
        warn_nil(warn, "ffmpeg unavailable: #{e.message}")
      end

      def reset_verified_cache!
        @verified.clear
      end

      def host_os_name(host_os)
        case host_os
        when /darwin/ then 'darwin'
        when /linux/ then 'linux'
        when /mswin|mingw|cygwin|windows/ then 'windows'
        end
      end

      def host_cpu_name(host_cpu)
        if host_cpu.match?(/arm64|aarch64/)
          'arm64'
        elsif host_cpu.match?(/x86_64|x64|amd64/)
          'x64'
        end
      end

      # Returns [path_or_nil, final]. final means "do not try to download".
      def lookup(env, manifest, warn, platform)
        override = env['RAIDER_FFMPEG_PATH']
        if override && !override.empty?
          return [override, true] if executable_file?(override)

          warn.call('RAIDER_FFMPEG_PATH is not an executable file; ignoring')
        end
        cached_lookup(env, manifest, warn, platform)
      end

      def cached_lookup(env, manifest, warn, platform)
        sha = manifest[:assets][platform.to_s]&.fetch(:sha256, nil)
        path = cached_path(env:, manifest:, platform:)
        return [nil, false] unless platform && sha && executable_file?(path)
        return [path, true] if verified_cached?(path, sha)

        FileUtils.rm_f(path)
        warn.call('cached ffmpeg failed checksum; video disabled')
        [nil, true]
      end

      def verified_cached?(path, sha256)
        key = verification_key(path, sha256)
        return true if @verified[key]

        ok = verified?(path, sha256)
        @verified[key] = true if ok
        ok
      end

      def verification_key(path, sha256)
        stat = File.stat(path)
        [path, stat.ino, stat.mtime.to_f, stat.ctime.to_f, stat.size, sha256]
      end

      def provision(env, manifest, fetch, warn, platform)
        asset = manifest[:assets][platform.to_s]
        unless asset
          label = platform || "#{RbConfig::CONFIG['host_os']}/#{RbConfig::CONFIG['host_cpu']}"
          return warn_nil(warn, "no ffmpeg build for this platform (#{label})")
        end
        return warn_nil(warn, 'ffmpeg build not published yet') unless asset[:sha256]
        return warn_nil(warn, "refusing non-https ffmpeg url: #{asset[:url]}") unless https?(asset[:url])

        download(cached_path(env:, manifest:, platform:), asset, fetch, warn)
      end

      def download(destination, asset, fetch, warn)
        part = "#{destination}.#{Process.pid}.#{SecureRandom.hex(4)}.part"
        begin
          FileUtils.mkdir_p(File.dirname(destination))
          fetch.call(asset[:url], part)
          return warn_nil(warn, "ffmpeg checksum mismatch for #{asset[:url]}; download discarded") unless verified?(part, asset[:sha256])

          File.chmod(0o755, part)
          # Rename wins: if another process already installed a valid binary, keep it.
          File.rename(part, destination) unless File.file?(destination) && verified?(destination, asset[:sha256])
          @verified[verification_key(destination, asset[:sha256])] = true
          destination
        rescue StandardError => e
          warn_nil(warn, "ffmpeg download failed: #{e.message}")
        ensure
          FileUtils.rm_f(part)
        end
      end

      def verified?(path, sha256)
        Digest::SHA256.file(path).hexdigest.casecmp?(sha256)
      end

      def executable_file?(path)
        File.file?(path) && File.executable?(path)
      end

      def https?(url)
        URI(url).scheme == 'https'
      rescue URI::InvalidURIError
        false
      end

      def warn_nil(warn, message)
        warn.call(message)
        nil
      end
    end
  end
end
