# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'rbconfig'

# Downloads the latest Raider Desktop release for the current platform.
# Uses the GitHub API to discover the latest release and match the right artifact.
# :reek:TooManyStatements { enabled: false }
# :reek:FeatureEnvy { enabled: false }
module DesktopDownloader
  REPO = 'RaiderHQ/raider_desktop'
  API_URL = "https://api.github.com/repos/#{REPO}/releases/latest".freeze

  PLATFORM_PATTERNS = {
    'mac_arm' => /\.dmg$/i,
    'mac_intel' => /\.dmg$/i,
    'windows' => /setup\.exe$/i,
    'linux_deb' => /\.deb$/i,
    'linux_appimage' => /\.AppImage$/i
  }.freeze

  HTTP_OPEN_TIMEOUT = 10
  HTTP_READ_TIMEOUT = 15

  class << self
    def download(destination_dir = nil)
      destination_dir ||= default_download_dir
      asset = find_asset
      unless asset
        warn '[Ruby Raider] No desktop release found for your platform'
        return nil
      end

      destination = File.join(destination_dir, asset[:name])
      puts "Downloading Raider Desktop (#{asset[:name]})..."
      download_file(asset[:url], destination)
      puts "Downloaded to: #{destination}"
      destination
    end

    def latest_version
      cached_release&.dig('tag_name')
    end

    def download_url
      asset = find_asset
      asset&.dig(:url)
    end

    # Clear cached release data (useful between operations or for testing)
    def clear_cache
      @cached_release = :unset
    end

    def platform
      host_os = RbConfig::CONFIG['host_os']
      arch = RbConfig::CONFIG['host_cpu']

      case host_os
      when /darwin|mac os/i
        arch =~ /arm|aarch64/i ? 'mac_arm' : 'mac_intel'
      when /mswin|mingw|cygwin|windows/i
        'windows'
      when /linux/i
        'linux_appimage'
      else
        'linux_appimage'
      end
    end

    def platform_display_name
      case platform
      when 'mac_arm' then 'macOS (Apple Silicon)'
      when 'mac_intel' then 'macOS (Intel)'
      when 'windows' then 'Windows'
      when 'linux_deb' then 'Linux (deb)'
      when 'linux_appimage' then 'Linux (AppImage)'
      else 'Unknown'
      end
    end

    private

    def find_asset
      release = cached_release
      return nil unless release

      assets = release['assets'] || []
      pattern = PLATFORM_PATTERNS[platform]
      return nil unless pattern

      matched = assets.find { |a| a['name'].match?(pattern) }
      return nil unless matched

      { name: matched['name'], url: matched['browser_download_url'], size: matched['size'] }
    end

    # Cache release data to avoid duplicate GitHub API calls
    # (latest_version, find_asset, and download_url all need the same data)
    def cached_release
      return @cached_release if defined?(@cached_release) && @cached_release != :unset

      @cached_release = fetch_latest_release
    end

    def fetch_latest_release
      uri = URI(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = HTTP_OPEN_TIMEOUT
      http.read_timeout = HTTP_READ_TIMEOUT
      response = http.get(uri.request_uri)
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      warn "[Ruby Raider] GitHub API timed out: #{e.message}"
      nil
    rescue StandardError => e
      warn "[Ruby Raider] Failed to check releases: #{e.message}"
      nil
    end

    def download_file(url, destination)
      FileUtils.mkdir_p(File.dirname(destination))
      uri = URI(url)
      follow_redirects(uri, destination)
    end

    def follow_redirects(uri, destination, limit = 5)
      raise 'Too many redirects' if limit.zero?

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                          open_timeout: HTTP_OPEN_TIMEOUT, read_timeout: 60) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request) do |response|
          case response
          when Net::HTTPRedirection
            follow_redirects(URI(response['location']), destination, limit - 1)
          when Net::HTTPSuccess
            write_response(response, destination)
          else
            raise "Download failed: #{response.code} #{response.message}"
          end
        end
      end
    end

    def write_response(response, destination)
      total = response['content-length']&.to_i
      downloaded = 0
      File.open(destination, 'wb') do |file|
        response.read_body do |chunk|
          file.write(chunk)
          downloaded += chunk.size
          print_progress(downloaded, total) if total&.positive?
        end
      end
      puts
    end

    def print_progress(downloaded, total)
      percent = (downloaded * 100.0 / total).round(1)
      bar_width = 30
      filled = (percent / 100.0 * bar_width).round
      bar = "#{'=' * filled}#{' ' * (bar_width - filled)}"
      mb = (downloaded / 1_048_576.0).round(1)
      total_mb = (total / 1_048_576.0).round(1)
      print "\r  [#{bar}] #{percent}% (#{mb}/#{total_mb} MB)"
    end

    def default_download_dir
      downloads = File.expand_path('~/Downloads')
      File.directory?(downloads) ? downloads : Dir.pwd
    end
  end
end
