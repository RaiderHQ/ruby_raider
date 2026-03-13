# frozen_string_literal: true

require 'tty-prompt'
require_relative '../generators/invoke_generators'

class MenuGenerator
  attr_reader :prompt, :name

  include InvokeGenerators

  def initialize(project_name)
    @prompt = TTY::Prompt.new
    @name = project_name
  end

  def generate_choice_menu
    prompt.select('Please select your automation framework') do |menu|
      select_automation_framework(menu)
    end
  end

  def choose_test_framework(automation)
    return choose_mobile_platform if automation == 'appium'

    select_test_framework(automation)
  end

  def set_up_framework(options)
    structure = {
      automation: options[:automation],
      framework: options[:framework],
      ci_platform: options[:ci_platform],
      reporter: options[:reporter],
      accessibility: options[:accessibility],
      visual: options[:visual],
      performance: options[:performance],
      ruby_version: options[:ruby_version],
      name: @name
    }
    generate_framework(structure)
    system "cd #{name} && gem install bundler && bundle install"
    offer_desktop_download
  end

  def choose_mobile_platform
    prompt.select('Please select your mobile platform') do |menu|
      menu.choice :iOS, -> { choose_test_framework 'ios' }
      menu.choice :Android, -> { choose_test_framework 'android' }
      menu.choice :Cross_Platform, -> { choose_test_framework 'cross_platform' }
      menu.choice :Quit, -> { exit }
    end
  end

  private

  def offer_desktop_download
    return unless prompt.yes?('Would you like to download Raider Desktop (GUI companion app)?')

    require_relative '../utilities/desktop_downloader'
    version = DesktopDownloader.latest_version
    unless version
      prompt.warn('Could not reach GitHub releases. You can download it later with: raider u desktop')
      return
    end

    prompt.say("Downloading Raider Desktop v#{version} for #{DesktopDownloader.platform_display_name}...")
    result = DesktopDownloader.download
    if result
      prompt.ok("Downloaded to: #{result}")
    else
      prompt.warn('No release found for your platform. Visit: https://github.com/RaiderHQ/raider_desktop/releases')
    end
  end

  def select_test_framework(automation)
    prompt.select('Please select your test framework') do |menu|
      menu.choice :Cucumber, -> { select_ci_platform('Cucumber', automation) }
      menu.choice :Rspec, -> { select_ci_platform('Rspec', automation) }
      menu.choice :Minitest, -> { select_ci_platform('Minitest', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  FrameworkOptions = Struct.new(:automation, :framework, :ci_platform, :reporter, :accessibility, :visual, :performance,
                               :ruby_version)

  def create_framework_options(params)
    FrameworkOptions.new(params[:automation], params[:framework], params[:ci_platform], params[:reporter],
                         params[:accessibility], params[:visual], params[:performance], params[:ruby_version])
  end

  def select_reporter(framework, automation_type, ci_platform = nil)
    prompt.select('Select your test reporter') do |menu|
      menu.choice :Allure, -> { select_accessibility(framework, automation_type, ci_platform, 'allure') }
      menu.choice :JUnit, -> { select_accessibility(framework, automation_type, ci_platform, 'junit') }
      menu.choice :JSON, -> { select_accessibility(framework, automation_type, ci_platform, 'json') }
      menu.choice :Both, -> { select_accessibility(framework, automation_type, ci_platform, 'both') }
      menu.choice :All, -> { select_accessibility(framework, automation_type, ci_platform, 'all') }
      menu.choice :None, -> { select_accessibility(framework, automation_type, ci_platform, 'none') }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_accessibility(framework, automation_type, ci_platform = nil, reporter = nil)
    return create_framework(framework, automation_type, ci_platform:, reporter:) if mobile_automation?(automation_type)

    prompt.select('Add accessibility testing (axe)?') do |menu|
      menu.choice :Yes, -> { select_visual(framework, automation_type, ci_platform, reporter, accessibility: true) }
      menu.choice :No, -> { select_visual(framework, automation_type, ci_platform, reporter) }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_visual(framework, automation_type, ci_platform = nil, reporter = nil, accessibility: false)
    prompt.select('Add visual regression testing?') do |menu|
      menu.choice :Yes, lambda {
        select_performance(framework, automation_type, ci_platform, reporter, accessibility:, visual: true)
      }
      menu.choice :No, lambda {
        select_performance(framework, automation_type, ci_platform, reporter, accessibility:)
      }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_performance(framework, automation_type, ci_platform = nil, reporter = nil, accessibility: false,
                         visual: false)
    prompt.select('Add Lighthouse performance auditing?') do |menu|
      menu.choice :Yes, lambda {
        select_ruby_version(framework, automation_type, ci_platform:, reporter:, accessibility:, visual:,
                            performance: true)
      }
      menu.choice :No, lambda {
        select_ruby_version(framework, automation_type, ci_platform:, reporter:, accessibility:, visual:)
      }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_ruby_version(framework, automation_type, ci_platform: nil, reporter: nil, accessibility: false,
                          visual: false, performance: false)
    prompt.select('Select Ruby version for your project') do |menu|
      menu.choice :'3.4 (latest)', lambda {
        create_framework(framework, automation_type, ci_platform:, reporter:, accessibility:, visual:, performance:,
                         ruby_version: '3.4')
      }
      menu.choice :'3.3', lambda {
        create_framework(framework, automation_type, ci_platform:, reporter:, accessibility:, visual:, performance:,
                         ruby_version: '3.3')
      }
      menu.choice :'3.2', lambda {
        create_framework(framework, automation_type, ci_platform:, reporter:, accessibility:, visual:, performance:,
                         ruby_version: '3.2')
      }
      menu.choice :'3.1', lambda {
        create_framework(framework, automation_type, ci_platform:, reporter:, accessibility:, visual:, performance:,
                         ruby_version: '3.1')
      }
      menu.choice :Quit, -> { exit }
    end
  end

  def mobile_automation?(automation_type)
    %w[ios android cross_platform].include?(automation_type)
  end

  def create_framework(framework, automation_type, ci_platform: nil, reporter: nil, accessibility: false,
                       visual: false, performance: false, ruby_version: nil)
    options = create_framework_options(automation: automation_type,
                                       framework: framework.downcase,
                                       ci_platform:,
                                       reporter:,
                                       accessibility:,
                                       visual:,
                                       performance:,
                                       ruby_version:)

    puts 'Chosen Options:'
    puts "  Automation Type: #{options[:automation]}"
    puts "  Framework: #{options[:framework]}"
    puts "  CI Platform: #{options[:ci_platform]}" if options[:ci_platform]
    puts "  Reporter: #{options[:reporter]}" if options[:reporter]
    puts '  Accessibility: enabled' if options[:accessibility]
    puts '  Visual Testing: enabled' if options[:visual]
    puts '  Performance Auditing: enabled' if options[:performance]
    puts "  Ruby Version: #{options[:ruby_version]}" if options[:ruby_version]

    set_up_framework(options)
    prompt.say("You have chosen to use #{framework} with #{automation_type}")
  end

  def yes_no_menu_choices
    {
      Yes: -> { true },
      No: -> { false },
      Quit: -> { exit }
    }
  end

  def select_automation_framework(menu)
    automation_options(menu)
    menu.choice :Quit, -> { exit }
  end

  def automation_options(menu)
    menu.choice :Selenium, -> { choose_test_framework('selenium') }
    menu.choice :Capybara, -> { choose_test_framework('capybara') }
    menu.choice :Appium, -> { choose_test_framework('appium') }
    menu.choice :Watir, -> { choose_test_framework('watir') }
  end

  def select_ci_platform(framework, automation)
    prompt.select('Would you like to configure CI?') do |menu|
      menu.choice :'Github Actions', -> { select_reporter(framework, automation, 'github') }
      menu.choice :'Gitlab CI/CD', -> { select_reporter(framework, automation, 'gitlab') }
      menu.choice :No, -> { select_reporter(framework, automation) }
      menu.choice :Quit, -> { exit }
    end
  end
end
