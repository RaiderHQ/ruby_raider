# frozen_string_literal: true

require 'thor'
require_relative '../utilities/utilities'

class UtilityCommands < Thor
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

  desc 'config', 'Creates a new config file'
  option :path,
         type: :string, required: false, desc: 'The path where your config file will be created', aliases: '-p'
  option :delete,
         type: :boolean, required: false, desc: 'This will delete the selected config file', aliases: '-d'

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

  desc 'debug [on/off]', 'Toggles debug mode for failure diagnostics and logging'

  def debug(toggle)
    enabled = %w[on true 1 yes].include?(toggle.downcase)
    Utilities.debug = enabled
    state = enabled ? 'enabled' : 'disabled'
    say "Debug mode #{state}", :green
  end

  desc 'start_appium', 'It starts the appium server'
  def start_appium
    system 'appium  --base-path /wd/hub'
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

  desc 'llm [PROVIDER]', 'Configures the LLM provider (openai, anthropic, ollama)'
  option :key, type: :string, required: false, desc: 'API key for the provider', aliases: '-k'
  option :model, type: :string, required: false, desc: 'Model name to use', aliases: '-m'
  option :url, type: :string, required: false, desc: 'API URL (for ollama)', aliases: '-u'
  option :status, type: :boolean, required: false, desc: 'Show current LLM configuration', aliases: '-s'

  def llm(provider = nil)
    if options[:status] || provider.nil?
      show_llm_status
      return
    end
    configure_llm(provider)
  end

  no_commands do
    def configure_llm(provider)
      unless %w[openai anthropic ollama].include?(provider)
        say "Unknown provider '#{provider}'. Choose: openai, anthropic, ollama", :red
        return
      end

      Utilities.llm_provider = provider
      Utilities.llm_api_key = options[:key] if options[:key]
      Utilities.llm_model = options[:model] if options[:model]
      Utilities.llm_url = options[:url] if options[:url]
      say "LLM configured: #{provider}", :green
    end

    def show_llm_status
      require_relative '../llm/client'
      status = Llm::Client.status
      if status[:configured]
        say "Provider: #{status[:provider]}"
        say "Model: #{status[:model] || 'default'}"
        say "Available: #{status[:available] ? 'yes' : 'no'}"
      else
        say 'No LLM configured. Use: raider u llm <provider>', :yellow
        say '  Providers: openai, anthropic, ollama'
        say '  Example:   raider u llm ollama'
        say '  Example:   raider u llm openai -k sk-...'
      end
    end
  end
end
