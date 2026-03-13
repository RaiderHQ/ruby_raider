# frozen_string_literal: true

require_relative '../../lib/utilities/desktop_downloader'

describe DesktopDownloader do
  describe '.platform' do
    it 'returns a recognized platform string' do
      expect(%w[mac_arm mac_intel windows linux_appimage linux_deb]).to include(described_class.platform)
    end
  end

  describe '.platform_display_name' do
    it 'returns a human-readable name' do
      expect(described_class.platform_display_name).to be_a(String)
      expect(described_class.platform_display_name).not_to eq('Unknown')
    end

    it 'matches the detected platform' do
      expected_names = {
        'mac_arm' => 'macOS (Apple Silicon)',
        'mac_intel' => 'macOS (Intel)',
        'windows' => 'Windows',
        'linux_deb' => 'Linux (deb)',
        'linux_appimage' => 'Linux (AppImage)'
      }
      expect(described_class.platform_display_name).to eq(expected_names[described_class.platform])
    end
  end

  describe 'PLATFORM_PATTERNS' do
    it 'has patterns for all supported platforms' do
      expect(described_class::PLATFORM_PATTERNS.keys).to contain_exactly(
        'mac_arm', 'mac_intel', 'windows', 'linux_deb', 'linux_appimage'
      )
    end

    it 'mac patterns match .dmg files' do
      expect('Raider-Desktop-1.0.0.dmg').to match(described_class::PLATFORM_PATTERNS['mac_arm'])
      expect('Raider-Desktop-1.0.0.dmg').to match(described_class::PLATFORM_PATTERNS['mac_intel'])
    end

    it 'windows pattern matches setup.exe files' do
      expect('Raider-Desktop-1.0.0-setup.exe').to match(described_class::PLATFORM_PATTERNS['windows'])
    end

    it 'linux deb pattern matches .deb files' do
      expect('raider-desktop_1.0.0_amd64.deb').to match(described_class::PLATFORM_PATTERNS['linux_deb'])
    end

    it 'linux appimage pattern matches .AppImage files' do
      expect('Raider-Desktop-1.0.0.AppImage').to match(described_class::PLATFORM_PATTERNS['linux_appimage'])
    end

    it 'does not cross-match patterns' do
      expect('Raider-Desktop.dmg').not_to match(described_class::PLATFORM_PATTERNS['windows'])
      expect('Raider-Desktop-setup.exe').not_to match(described_class::PLATFORM_PATTERNS['mac_arm'])
    end
  end

  describe '.latest_version' do
    context 'when GitHub API is reachable' do
      it 'returns a version string or nil' do
        version = described_class.latest_version
        # May be nil if rate-limited or offline, that's OK
        expect(version).to be_nil.or(match(/\Av?\d+\.\d+/))
      end
    end
  end

  describe '.download_url' do
    context 'when GitHub API is reachable' do
      it 'returns a URL string or nil' do
        url = described_class.download_url
        expect(url).to be_nil.or(match(%r{\Ahttps://}))
      end
    end
  end

  describe 'REPO' do
    it 'points to the correct GitHub repository' do
      expect(described_class::REPO).to eq('RaiderHQ/raider_desktop')
    end
  end

  describe 'API_URL' do
    it 'is a valid GitHub releases API endpoint' do
      expect(described_class::API_URL).to eq(
        'https://api.github.com/repos/RaiderHQ/raider_desktop/releases/latest'
      )
    end
  end
end
