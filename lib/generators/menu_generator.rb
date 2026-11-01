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
      ci: options[:ci],
      examples: options[:examples],
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
      menu.choice :Cucumber, -> { select_examples('Cucumber', automation) }
      menu.choice :Rspec, -> { select_examples('Rspec', automation) }
      menu.choice :Quit, -> { exit }
    end
  end

  # Watir templates are frozen, so Watir projects always get the example tests and skip this question
  def select_examples(framework, automation_type)
    return select_accessibility(framework, automation_type, examples: true) if automation_type == 'watir'

    prompt.select('Do you want example tests?') do |menu|
      menu.choice :Yes, -> { select_accessibility(framework, automation_type, examples: true) }
      menu.choice :No, -> { select_accessibility(framework, automation_type, examples: false) }
      menu.choice :Quit, -> { exit }
    end
  end

  FrameworkOptions = Struct.new(:automation, :framework, :accessibility, :ci, :examples)

  def create_framework_options(params)
    FrameworkOptions.new(params[:automation], params[:framework], params[:accessibility], params[:ci],
                         params[:examples])
  end

  def select_accessibility(framework, automation_type, examples: true)
    return create_framework(framework, automation_type, examples:) if mobile_automation?(automation_type)

    prompt.select('Add accessibility testing (axe)?') do |menu|
      menu.choice :Yes, -> { select_ci(framework, automation_type, accessibility: true, examples:) }
      menu.choice :No, -> { select_ci(framework, automation_type, accessibility: false, examples:) }
      menu.choice :Quit, -> { exit }
    end
  end

  def select_ci(framework, automation_type, accessibility:, examples: true)
    prompt.select('Which CI provider?') do |menu|
      menu.choice 'GitHub Actions', -> { create_framework(framework, automation_type, accessibility:, examples:) }
      menu.choice 'Azure Pipelines', lambda {
        create_framework(framework, automation_type, accessibility:, ci_provider: 'azure', examples:)
      }
      menu.choice :Quit, -> { exit }
    end
  end

  def mobile_automation?(automation_type)
    %w[ios android cross_platform].include?(automation_type)
  end

  def create_framework(framework, automation_type, accessibility: false, ci_provider: nil, examples: true)
    options = create_framework_options(automation: automation_type,
                                       framework: framework.downcase,
                                       accessibility:, ci: ci_provider, examples:)

    puts 'Chosen Options:'
    puts "  Automation Type: #{options[:automation]}"
    puts "  Framework: #{options[:framework]}"
    puts '  Accessibility: enabled' if options[:accessibility]
    puts '  CI: Azure Pipelines' if options[:ci] == 'azure'
    puts '  Example tests: none' unless options[:examples]

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
