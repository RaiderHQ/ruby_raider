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
      accessibility: options[:accessibility],
      visual: options[:visual],
      performance: options[:performance],
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
      menu.choice :Cucumber, -> { select_accessibility('Cucumber', automation) }
      menu.choice :Rspec, -> { select_accessibility('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  FrameworkOptions = Struct.new(:automation, :framework, :accessibility, :visual, :performance)

  def create_framework_options(params)
    FrameworkOptions.new(params[:automation], params[:framework],
                         params[:accessibility], params[:visual], params[:performance])
  end

  def select_accessibility(framework, automation_type)
    return create_framework(framework, automation_type) if mobile_automation?(automation_type)

    prompt.select('Add accessibility testing (axe)?') do |menu|
      menu.choice :Yes, -> { select_visual(framework, automation_type, accessibility: true) }
      menu.choice :No, -> { select_visual(framework, automation_type) }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_visual(framework, automation_type, accessibility: false)
    prompt.select('Add visual regression testing?') do |menu|
      menu.choice :Yes, lambda {
        select_performance(framework, automation_type, accessibility:, visual: true)
      }
      menu.choice :No, lambda {
        select_performance(framework, automation_type, accessibility:)
      }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_performance(framework, automation_type, accessibility: false, visual: false)
    prompt.select('Add Lighthouse performance auditing?') do |menu|
      menu.choice :Yes, lambda {
        create_framework(framework, automation_type, accessibility:, visual:,
                         performance: true)
      }
      menu.choice :No, lambda {
        create_framework(framework, automation_type, accessibility:, visual:)
      }
      menu.choice :Quit, -> { exit }
    end
  end

  def mobile_automation?(automation_type)
    %w[ios android cross_platform].include?(automation_type)
  end

  def create_framework(framework, automation_type, accessibility: false,
                       visual: false, performance: false)
    options = create_framework_options(automation: automation_type,
                                       framework: framework.downcase,
                                       accessibility:,
                                       visual:,
                                       performance:)

    puts 'Chosen Options:'
    puts "  Automation Type: #{options[:automation]}"
    puts "  Framework: #{options[:framework]}"
    puts '  Accessibility: enabled' if options[:accessibility]
    puts '  Visual Testing: enabled' if options[:visual]
    puts '  Performance Auditing: enabled' if options[:performance]

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
    menu.choice :Appium, -> { choose_test_framework('appium') }
    menu.choice :Watir, -> { choose_test_framework('watir') }
  end
end
