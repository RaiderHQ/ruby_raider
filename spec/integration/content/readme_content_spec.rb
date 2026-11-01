# frozen_string_literal: true

require_relative 'content_helper'

describe 'Generated Readme content' do
  FRAMEWORKS.product(AUTOMATION_TYPES).each do |framework, automation|
    context "with #{framework} and #{automation}, the Video replay section" do
      subject(:section) { readme[/^### Video replay\n.*?(?=^##)/m]&.gsub(/\s+/, ' ') }

      let(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }
      let(:web) { %w[selenium watir].include?(automation) }

      it 'exists and covers the defaults, VIDEO=off, the install commands and the cache' do
        expect(section).not_to be_nil
        expect(section).to include('only for failing tests', 'VIDEO=off', 'raider u video install',
                                   'raider u video status', '~/.cache/raider', 'RAIDER_FFMPEG_PATH',
                                   'RAIDER_CACHE_DIR', 'raider-results/attachments/')
      end

      it 'says that video needs RAIDER_FFMPEG_PATH until the ffmpeg release is published' do
        expect(section).to include('ffmpeg-7.1', 'not published yet')
      end

      it 'names the right video format and how to turn video off for this project' do
        if web
          expect(section).to include('video.webm', 'raider u video off', 'raider u video on', 'video:')
        elsif %w[android ios].include?(automation)
          expect(section).to include('video.mp4', 'raider u video off', 'creates `config/config.yml`')
          expect(section).not_to include('no `config/config.yml`')
        else
          expect(section).to include('video.mp4', 'raider u video off')
        end
      end

      it 'says where mobile recording needs ffmpeg and how long it records' do
        limits = { 'ios' => ['1800 s'], 'android' => ['180 s'], 'cross_platform' => ['1800 s', '180 s'] }
        if web
          expect(section).not_to include('Appium server host')
        else
          expect(section).to include('`ffmpeg` on the Appium server host', 'iOS', 'longer than 180 s',
                                     'time_limit', *limits.fetch(automation))
          expect(section).not_to include('do not use ffmpeg')
        end
      end

      it 'lists the known limits of web recording' do
        if web
          expect(section).to include('after each page load, click and text change', 'next frame',
                                     'one recorded driver per process')
        else
          expect(section).not_to include('next frame')
        end
      end
    end
  end

  AUTOMATION_TYPES.each do |automation|
    context "with rspec and #{automation}" do
      subject(:readme) { read_generated("#{FrameworkIndex::RSPEC}_#{automation}", 'Readme.md') }

      it 'has a Reporting section' do
        expect(readme).to include('## Reporting')
      end

      it 'documents local results, upload settings and the raider_reporter README' do
        expect(readme).to include('raider-results/', 'RAIDER_TOKEN', 'RAIDER_ENDPOINT',
                                  'https://github.com/RaiderHQ/raider_reporter')
      end

      it 'explains quarantine in CI' do
        expect(readme).to include('### Quarantine', 'RAIDER_QUARANTINE', 'raider-reporter exec')
      end

      it 'explains the quality gate' do
        expect(readme).to include('### Quality gate', 'RAIDER_GATE=1', 'Gate page', 'raider/gate',
                                  'raider-reporter gate', 'raider-gate', 'exits 1 when the gate fails',
                                  '2 when it gets no verdict', 'RAIDER_GATE_TIMEOUT', 'RAIDER_SHARD_TOTAL',
                                  'RAIDER_SHARD_INDEX')
      end

      it 'points to the local HTML report' do
        expect(readme).to include('raider-results/index.html')
        expect(readme).not_to match(/allure/i)
      end
    end

    context "with cucumber and #{automation}" do
      subject(:readme) { read_generated("#{FrameworkIndex::CUCUMBER}_#{automation}", 'Readme.md') }

      it 'has a Reporting section' do
        expect(readme).to include('## Reporting')
      end

      it 'documents local results, upload settings, plugin mode and the raider_reporter README' do
        expect(readme).to include('raider-results/', 'RAIDER_TOKEN', 'RAIDER_ENDPOINT', 'features/support/env.rb',
                                  'https://github.com/RaiderHQ/raider_reporter')
      end

      it 'explains quarantine in CI' do
        expect(readme).to include('### Quarantine', 'RAIDER_QUARANTINE', 'raider-reporter exec')
      end

      it 'explains the quality gate' do
        expect(readme).to include('### Quality gate', 'RAIDER_GATE=1', 'Gate page', 'raider/gate',
                                  'raider-reporter gate', 'raider-gate', 'exits 1 when the gate fails',
                                  '2 when it gets no verdict', 'RAIDER_GATE_TIMEOUT', 'RAIDER_SHARD_TOTAL',
                                  'RAIDER_SHARD_INDEX')
      end

      it 'does not mention Allure' do
        expect(readme).not_to match(/allure/i)
      end
    end
  end

  FRAMEWORKS.product(AUTOMATION_TYPES).each do |framework, automation|
    context "with #{framework} and #{automation}, the login reuse section" do
      subject(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

      if %w[selenium watir].include?(automation)
        it 'documents the tags, other roles, max_age, the env switch and the secrets warning' do
          section = readme[/^## Reusing the login\n.*?(?=^##)/m].gsub(/\s+/, ' ')
          expect(section).to include('`:logged_in`', '`@logged_in`', "SessionState.new(driver, name: 'admin')",
                                     'browser.driver', 'login_state', 'max_age', 'RAIDER_LOGIN_STATE=off',
                                     'RAIDER_LOGIN_STATE=refresh', '.raider/auth/', 'git-ignored',
                                     'live session tokens', 'must not be committed, cached or uploaded')
        end

        it 'is its own ## section, straight before Reporting, so Sponsors does not nest under it' do
          heading = readme.index("\n## Reusing the login\n")
          expect(heading).not_to be_nil
          expect(readme[(heading + 1)..][/\n## .*/]).to eq("\n## Reporting")
          sponsors = readme.index("\n### Sponsors") || readme.size
          expect(readme[0...sponsors].scan(/\n## .*/).last).not_to eq("\n## Reusing the login")
        end
      else
        it 'does not mention login reuse' do
          expect(readme).not_to include('Reusing the login', 'RAIDER_LOGIN_STATE', '.raider/auth/')
        end
      end
    end
  end
end

describe 'Generated Readme: How the framework works' do
  def section_of(readme)
    readme[/^## How the framework works\n.*?(?=^## )/m]
  end

  FRAMEWORKS.each do |framework|
    context "with #{framework} and selenium" do
      subject(:readme) { read_generated("#{framework}_selenium", 'Readme.md') }

      it 'sits between Getting Started and Reusing the login' do
        works = readme.index("\n## How the framework works\n")
        expect(works).not_to be_nil
        expect(readme.index("\n## Getting Started\n")).to be < works
        expect(readme.index("\n## Reusing the login\n")).to be > works
      end

      it 'covers the web wait helper, chaining, .native, absence checks and how to remove it' do
        section = section_of(readme)
        expect(section).to include('### Removing the wait helper', '.native',
                                   "find_element(css: '.form').find_element(id: 'email')",
                                   'select_by', 'hover', 'drag_and_drop', 'eventually', 'timeout: 0',
                                   'find_elements', 'config/config.yml', '[Reporting](#reporting)',
                                   '[Reusing the login](#reusing-the-login)', 'parallel_tests', 'HEADLESS',
                                   framework == 'rspec' ? 'RETRY_COUNT' : '--retry 2')
        expect(section).not_to include('scroll_to', 'swipe')
      end

      it 'lists the five steps to remove the wait helper' do
        removal = section_of(readme)[/^### Removing the wait helper\n.*/m]
        expect(removal).to include('helpers/wait_helper.rb', 'helpers/raider_element.rb', 'include WaitHelper',
                                   'driver.find_element(**', 'Selenium::WebDriver::Wait.new', 'implicit_wait',
                                   'raider g')
        expect(removal.scan(/^\d\. /).size).to eq(5)
      end
    end

    %w[ios android cross_platform].each do |automation|
      context "with #{framework} and #{automation}" do
        subject(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

        it 'sits between Getting Started and Reporting' do
          works = readme.index("\n## How the framework works\n")
          expect(works).not_to be_nil
          expect(readme.index("\n## Getting Started\n")).to be < works
          expect(readme.index("\n## Reporting\n")).to be > works
        end

        it 'covers the mobile method set, per-OS locators, Appium setup and how to remove the wait helper' do
          section = section_of(readme)
          expect(section).to include('swipe', 'scroll_to', 'tap', 'capabilities.yml', 'raider u start_appium',
                                     '### Removing the wait helper', '.native', '[Reporting](#reporting)',
                                     'timeout: 15')
          expect(section).not_to include('select_by', 'hover', 'drag_and_drop', 'Reusing the login')
          expect(section).to include('ios: {') if automation == 'cross_platform'
        end
      end
    end

    it "has no such section for #{framework} and watir" do
      expect(read_generated("#{framework}_watir", 'Readme.md')).not_to include('How the framework works')
    end
  end

  describe 'without example tests' do
    %w[rspec cucumber].product(%w[selenium ios cross_platform]).each do |framework, automation|
      context "with #{framework} and #{automation}" do
        subject(:readme) { read_generated(ensure_project(framework:, automation:, examples: false), 'Readme.md') }

        it 'still explains how the framework works' do
          expect(readme).to include('## How the framework works', '### The wait helper and RaiderElement')
        end

        it 'points at no example file' do
          expect(readme).not_to match(/login\.rb|account\.rb|header\.rb|home\.rb|pdp\.rb|users\.yml|model_factory|
                                       user_factory|login_page_spec|pdp_page_spec|login\.feature|home\.feature|
                                       login_steps|home_steps|account\ example|files\ in\ this\ project/x)
        end

        it 'says it has no example tests and how it grows with scaffolding' do
          expect(readme).to include('generated without example tests', 'raider g scaffold checkout')
        end
      end
    end

    %w[rspec cucumber].each do |framework|
      it "shows how to add the login hook for the project's own login page in #{framework}" do
        readme = read_generated(ensure_project(framework:, automation: 'selenium', examples: false), 'Readme.md')
        section = readme[/^## Reusing the login\n.*?(?=^## )/m]
        hook = framework == 'rspec' ? 'config.before(:each, :logged_in) do' : "Before('@logged_in') do"
        expect(section).to include(hook, 'SessionState.new(driver).reuse(')
      end
    end
  end
end
