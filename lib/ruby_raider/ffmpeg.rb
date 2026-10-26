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
    MANIFEST = {
      version: '7.1',
      assets: {
        'darwin-arm64' => { url: 'https://github.com/RaiderHQ/ruby_raider/releases/download/ffmpeg-7.1/ffmpeg-7.1-darwin-arm64', sha256: nil },
        'darwin-x64' => { url: 'https://github.com/RaiderHQ/ruby_raider/releases/download/ffmpeg-7.1/ffmpeg-7.1-darwin-x64', sha256: nil },
        'linux-x64' => { url: 'https://github.com/RaiderHQ/ruby_raider/releases/download/ffmpeg-7.1/ffmpeg-7.1-linux-x64', sha256: nil },
        'windows-x64' => { url: 'https://github.com/RaiderHQ/ruby_raider/releases/download/ffmpeg-7.1/ffmpeg-7.1-windows-x64.exe', sha256: nil }
      }
    }.freeze

    DEFAULT_WARN = ->(message) { warn("[video] #{message}") }

    class << self
      def platform(host_os: RbConfig::CONFIG['host_os'], host_cpu: RbConfig::CONFIG['host_cpu'])
        arm = host_cpu.match?(/arm64|aarch64/)
        x64 = host_cpu.match?(/x86_64|x64|amd64/)
        case host_os
        when /darwin/ then arm ? 'darwin-arm64' : (x64 ? 'darwin-x64' : nil) # rubocop:disable Style/NestedTernaryOperator
        when /linux/ then x64 ? 'linux-x64' : nil
        when /mswin|mingw|cygwin|windows/ then x64 ? 'windows-x64' : nil
        end
      end

      def cache_dir(env: ENV)
        override = env['RAIDER_CACHE_DIR']
        return override if override && !override.empty?

        local = env['LOCALAPPDATA']
        if platform == 'windows-x64' && local && !local.empty?
          File.join(local, 'raider')
        else
          File.join(Dir.home, '.cache', 'raider')
        end
      end

      # No network: the env override if executable, else the cached binary.
      def resolve(env: ENV, manifest: MANIFEST)
        override = env['RAIDER_FFMPEG_PATH']
        return override if override && !override.empty? && executable_file?(override)

        path = cached_path(env, manifest)
        path if path && executable_file?(path)
      end

      def ensure!(env: ENV, manifest: MANIFEST, fetch: method(:http_get), warn: DEFAULT_WARN)
        found = resolve(env:, manifest:)
        return found if found

        provision(env, manifest, fetch, warn)
      end

      def http_get(url, destination, limit = MAX_REDIRECTS)
        raise ArgumentError, "refusing non-https url: #{url}" unless https?(url)
        raise IOError, 'too many redirects' if limit.negative?

        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
          http.request(Net::HTTP::Get.new(uri)) do |response|
            case response
            when Net::HTTPSuccess
              File.open(destination, 'wb') { |file| response.read_body { |chunk| file.write(chunk) } }
            when Net::HTTPRedirection
              return http_get(URI.join(url, response['location']).to_s, destination, limit - 1)
            else
              raise IOError, "download failed: HTTP #{response.code}"
            end
          end
        end
      end

      private

      def provision(env, manifest, fetch, warn)
        asset = manifest[:assets][platform.to_s]
        return warn_nil(warn, "no ffmpeg build for this platform (#{RbConfig::CONFIG['host_os']}/#{RbConfig::CONFIG['host_cpu']})") unless asset
        return warn_nil(warn, 'ffmpeg build not published yet') unless asset[:sha256]
        return warn_nil(warn, "refusing non-https ffmpeg url: #{asset[:url]}") unless https?(asset[:url])

        download(cached_path(env, manifest), asset, fetch, warn)
      end

      def download(destination, asset, fetch, warn)
        FileUtils.mkdir_p(File.dirname(destination))
        part = "#{destination}.#{Process.pid}.#{SecureRandom.hex(4)}.part"
        begin
          fetch.call(asset[:url], part)
          return warn_nil(warn, "ffmpeg checksum mismatch for #{asset[:url]}; download discarded") unless verified?(part, asset[:sha256])

          File.chmod(0o755, part)
          # Rename wins: if another process already installed a valid binary, keep it.
          File.rename(part, destination) unless File.file?(destination) && verified?(destination, asset[:sha256])
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

      def cached_path(env, manifest)
        name = platform.to_s.start_with?('windows') ? 'ffmpeg.exe' : 'ffmpeg'
        File.join(cache_dir(env:), 'ffmpeg', manifest[:version], name)
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
