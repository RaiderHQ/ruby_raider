# frozen_string_literal: true

require 'thor'
require_relative '../utilities/utilities'

class UtilityCommands < Thor
  def self.exit_on_failure? = true

  desc 'path [PATH]', 'Sets the default path for scaffolding'
  option :feature,
         type: :boolean, required: false, desc: 'The default path for your features', aliases: '-f'
  option :helper,
         type: :boolean, required: false, desc: 'The default path for your helpers', aliases: '-h'
  option :spec,
         type: :boolean, required: false, desc: 'The default path for your specs', aliases: '-s'

  def path(default_path)
    type = options.empty? ? 'page' : options.keys.first
    Utilities.send("#{type}_path=", default_path)
  end

  desc 'url [URL]', 'Sets the default url for a project'

  def url(default_url)
    Utilities.url = default_url
  end

  desc 'browser [BROWSER]', 'Sets the default browser for a project'
  option :opts,
         type: :array, required: false, desc: 'The options you want your browser to run with', aliases: '-o'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser(default_browser = nil)
    Utilities.browser = default_browser if default_browser
    selected_options = options[:opts]
    browser_options(selected_options) if selected_options || options[:delete]
  end

  desc 'browser_options [OPTIONS]', 'Sets the browser arguments for the current browser (e.g. no-sandbox, headless)'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete your browser options', aliases: '-d'

  def browser_options(*opts)
    Utilities.browser_options = opts unless opts.empty?
    Utilities.delete_browser_options if options[:delete]
  end

  desc 'headless [on/off]', 'Toggles headless mode for browser tests'

  def headless(toggle)
    enabled = %w[on true 1 yes].include?(toggle.downcase)
    Utilities.headless = enabled
    state = enabled ? 'enabled' : 'disabled'
    say "Headless mode #{state}", :green
  end

  desc 'raid', 'It runs all the tests in a project'
  option :parallel,
         type: :boolean, required: false, desc: 'It runs the tests in parallel', aliases: '-p'
  option :opts,
         type: :array, required: false, desc: 'The options that your run will run with', aliases: '-o'

  def raid
    selected_options = options[:opts]
    if options[:parallel]
      Utilities.parallel_run(selected_options)
    else
      Utilities.run(selected_options)
    end
  end

  desc 'timeout [SECONDS]', 'Sets the default test timeout in seconds'

  def timeout(seconds)
    Utilities.timeout = seconds
  end

  desc 'viewport [DIMENSIONS]', 'Sets the default viewport size (e.g. 1920x1080, 375x812)'

  def viewport(dimensions)
    Utilities.viewport = dimensions
  end

  desc 'platform [PLATFORM]', 'Sets the default platform for a cross-platform project'

  def platform(platform)
    Utilities.platform = platform
  end

  desc 'start_appium', 'It starts the appium server'
  def start_appium
    system 'appium'
  end

  desc 'desktop', 'Downloads the Raider Desktop GUI application'
  option :path, type: :string, required: false,
                desc: 'Directory to save the download', aliases: '-p'

  def desktop
    require_relative '../utilities/desktop_downloader'
    version = DesktopDownloader.latest_version
    unless version
      say 'Could not reach GitHub releases. Check your internet connection.', :red
      return
    end

    say "Raider Desktop v#{version} available for #{DesktopDownloader.platform_display_name}"
    DesktopDownloader.download(options[:path])
    say 'Raider Desktop downloaded successfully!', :green
  end

  desc 'video [install|status|on|off]', 'Manages failure video recording (ffmpeg install, status, on/off)'

  def video(action)
    case action
    when 'install' then video_install
    when 'status' then video_status
    when 'on', 'off' then video_toggle(action == 'on')
    else
      say_error "Unknown video command '#{action}'. Use install|status|on|off", :red
      exit 1
    end
  end

  no_commands do
    def video_install
      require_relative '../ruby_raider/ffmpeg'
      path = RubyRaider::Ffmpeg.ensure!
      exit 1 unless path

      say path
    end

    def video_status
      require_relative '../ruby_raider/ffmpeg'
      path = RubyRaider::Ffmpeg.resolve
      source = path && path == ENV['RAIDER_FFMPEG_PATH'] ? '(RAIDER_FFMPEG_PATH)' : RubyRaider::Ffmpeg::MANIFEST[:version]
      say "ffmpeg #{source}: #{path || 'not installed'}"
    end

    def video_toggle(enabled)
      Utilities.video_enabled = enabled
      say "Failure video #{enabled ? 'enabled' : 'disabled'}", :green
    end
  end
end
