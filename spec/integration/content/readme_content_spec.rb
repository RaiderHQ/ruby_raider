# frozen_string_literal: true

require_relative 'content_helper'

describe 'Generated Readme content' do
  FRAMEWORKS.product(AUTOMATION_TYPES).each do |framework, automation|
    context "with #{framework} and #{automation}, the Video replay section" do
      subject(:section) { readme[/^### Video replay\n.*?(?=^##)/m]&.gsub(/\s+/, ' ') }

      let(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }
      let(:web) { automation == 'selenium' }

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

    context "with #{framework} and #{automation}, the Trace replay section" do
      subject(:section) { readme[/^### Trace replay\n.*?(?=^##)/m]&.gsub(/\s+/, ' ') }

      let(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

      if automation == 'selenium'
        it 'covers the defaults, TRACE=on, TRACE=off, the file location and how to open it' do
          expect(section).to include('only for failing tests', 'TRACE=on', 'TRACE=off', 'raider u trace off',
                                     'raider u trace on', 'raider-results/attachments/', 'Raider Desktop', 'Hideout',
                                     'helpers/trace_helper.rb')
          expect(section).to include('raider-results/attachments/<n>-trace.zip')
          expect(section).to include('`raider u trace on` and `raider u trace off` write `enabled:`')
          expect(section).not_to include('Both write')
        end

        it 'states the per-step cost and the caps' do
          expect(section).to include('one screenshot and one page HTML', 'max_mb', 'max_steps', 'trace:')
        end

        it 'allows at most one [trace] notice, plus one line when tracing stops' do
          expect(section).to include('at most one `[trace]` notice', 'one more `[trace]` line', 'tracing disabled for this run')
        end

        it 'limits network and console to Chrome, Edge or Firefox' do
          expect(section).to include('Chrome, Edge or Firefox', 'Safari', 'steps, screenshots and HTML')
        end

        it 'says what is hidden, what is kept and what is never captured' do
          expect(section).to include('password', 'RAIDER_SECRET_', 'page text', 'query strings', 'console text',
                                     'like the video', 'never captured', 'cookies')
          expect(section).to include('Failure messages can contain typed text too, because an assertion message is kept as it is')
        end

        it 'says how to remove the trace helper' do
          expect(readme).to include('Removing the trace helper', 'require_relative')
          expect(readme).not_to match(/allure/i)
          expect(readme).not_to include('—')
        end

        it 'says which element actions the trace records' do
          expect(section).to include('records `click`, `send_keys`, `clear` and `submit` with their locators',
                                     '`by_role` as `button, name: Save`', 'not steps')
        end
      else
        it 'does not mention trace replay' do
          expect(readme).not_to include('Trace replay', 'TRACE=', 'trace_helper')
        end
      end
    end

    context "with #{framework} and #{automation}, the network mocking section" do
      subject(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

      if automation == 'selenium'
        it 'documents the API, the examples, BIDI=off and how to remove the helper' do
          expect(readme).to include('## Mocking network requests', "mock_request('**/api/users', json: { users: [] })",
                                    'BIDI=off', '### Removing the network helper', 'status: 500',
                                    "block_request('**/*.png')", 'NetworkHelper::MockError')
          expect(readme).to include('expect { users.called? }.to be(true)',
                                    "expect { users.calls.first&.method }.to eq('GET')")
        end

        it 'names the files to edit for this framework' do
          section = readme[/^### Removing the network helper\n.*?(?=^##)/m]
          expect(section).to include('helpers/network_helper.rb', 'NetworkHelper.finish', 'raise mock_error')
          expect(section).to include(framework == 'rspec' ? 'config.include(NetworkHelper)' : 'World(NetworkHelper)')
        end

        it 'says that TRACE=off keeps BiDi on' do
          expect(readme).to include('BiDi stays on')
        end
      else
        it 'does not mention network mocking' do
          expect(readme).not_to include('Mocking network requests', 'NetworkHelper')
        end
      end
    end

    context "with #{framework} and #{automation}, the screenshot comparison section" do
      subject(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

      if automation == 'selenium'
        it 'documents the call, SCREENSHOTS=update, tolerances, CI baselines and removal' do
          expect(readme).to include('## Screenshot comparison', "match_screenshot('home')", 'SCREENSHOTS=update',
                                    'screenshots/baselines/', 'max_diff_pixels', 'Retina', 'Generate baselines where CI runs',
                                    '### Removing screenshot comparison')
        end

        it 'names the files to edit for this framework' do
          section = readme[/^### Removing screenshot comparison\n.*?(?=^##)/m]
          expect(section).to include('helpers/screenshot_helper.rb', 'ScreenshotHelper.reset', "gem 'chunky_png'")
          expect(section).to include(framework == 'rspec' ? 'config.include(ScreenshotHelper)' : 'World(ScreenshotHelper)')
        end
      else
        it 'does not mention screenshot comparison' do
          expect(readme).not_to include('Screenshot comparison', 'ScreenshotHelper', 'match_screenshot')
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
  end

  FRAMEWORKS.product(AUTOMATION_TYPES).each do |framework, automation|
    context "with #{framework} and #{automation}, the login reuse section" do
      subject(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

      if automation == 'selenium'
        it 'documents the tags, other roles, max_age, the env switch and the secrets warning' do
          section = readme[/^## Reusing the login\n.*?(?=^##)/m].gsub(/\s+/, ' ')
          expect(section).to include('`:logged_in`', "SessionState.new(driver, name: 'admin')",
                                     'login_state', 'max_age', 'RAIDER_LOGIN_STATE=off',
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

      it 'covers the folders, the settings, running the tests and the helpers without a wait helper' do
        section = section_of(readme)
        expect(section).to include('config/config.yml', '[Reporting](#reporting)', '[Reusing the login](#reusing-the-login)',
                                   'parallel_tests', 'HEADLESS', 'requires the Raider runtime',
                                   framework == 'rspec' ? 'RETRY_COUNT' : '--retry 2')
        expect(section).to include('`timeout`', '`strict`', '`actionability`')
        expect(section).not_to include('scroll_to', 'swipe', 'gesture_helper')
      end

      it 'has no wait helper, RaiderElement, eventually or implicit wait advice' do
        expect(readme).not_to match(/WaitHelper|RaiderElement|wait_helper|raider_element|eventually|wait helper/i)
        expect(readme).not_to include('Removing the wait helper', 'implicit_wait = ')
      end

      it 'documents the locators, with by_role, the exact form, strictness and find_elements' do
        locators = section_of(readme)[/^### Locators\n.*?(?=^### )/m].gsub(/\s+/, ' ')
        expect(locators).to include('id:', 'css:', 'xpath:', 'name:', 'class:', 'link_text:', 'label:', 'placeholder:',
                                    'alt:', 'title:', 'text:', 'test_id:', 'data-testid', 'RAIDER_TEST_ID_ATTRIBUTE',
                                    "by_role('button', name: 'Login')", 'exact:', 'include_hidden:', 'level:',
                                    "label: ['Email', { exact: true }]", 'matches more than one element',
                                    'AmbiguousMatch', 'find_elements')
      end

      it 'documents the waiting finds, the per-action checks, force and the settings' do
        waiting = section_of(readme)[/^### Waiting and actionability\n.*?(?=^### )/m].gsub(/\s+/, ' ')
        expect(waiting).to include('`find_element` and `find_elements` wait for a match', '`find_elements` returns `[]`',
                                   '| `click` | visible, enabled, not inert, stable, receives events |',
                                   '| `send_keys` | visible, enabled, editable, not inert |',
                                   '| `clear` | visible, enabled, editable, not inert |',
                                   '| `submit` | visible, enabled, not inert |',
                                   'force: true', 'Raider.actionability = false', 'RAIDER_STRICT', 'RAIDER_ACTIONABILITY',
                                   'RAIDER_TIMEOUT', 'RAIDER_QUIET', 'raider u strict', 'raider u actionability',
                                   'no such element: { id: "x" } (waited 10s)', 'NotActionable', 'select_by',
                                   'implicit wait')
        expect(waiting).not_to include('driver.manage.timeouts.implicit_wait')
      end

      it 'documents the matchers, wait:, the block form and its limits' do
        assertions = section_of(readme)[/^### Assertions\n.*?(?=^### )/m].gsub(/\s+/, ' ')
        expect(assertions).to include('have_text', 'have_value', 'have_attribute', 'be_visible', 'be_hidden', 'be_enabled',
                                      'be_disabled', 'be_checked', 'have_count', 'have_title', 'have_url', 'have_element',
                                      'have_css', 'have_xpath', 'wait: 5', 'expect { account_page.welcome_message }',
                                      'expect { value }.to eq(', 'raise_error', 'does not retry',
                                      'once per poll', 'aggregate_failures')
      end

      it 'lists the web helpers and the page base class without a wait helper' do
        section = section_of(readme)
        expect(section).to include('`driver_helper.rb` starts the browser', '`video_helper.rb`', '`session_state.rb`')
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

        it 'covers the folders, per-OS locators, Appium setup and the gesture helper' do
          section = section_of(readme)
          expect(section).to include('capabilities.yml', 'raider u start_appium', '[Reporting](#reporting)',
                                     'timeout: 15', 'http://127.0.0.1:4723', '`gesture_helper.rb`',
                                     '`swipe`', '`scroll_to`', 'requires the Raider runtime')
          expect(section).not_to include('select_by', 'hover', 'drag_and_drop', 'Reusing the login', '/wd/hub',
                                         'by_role', 'wait_helper', 'raider_element')
          expect(section).to include('ios: {') if automation == 'cross_platform'
        end

        it 'has no wait helper, RaiderElement or eventually' do
          expect(readme).not_to match(/WaitHelper|RaiderElement|wait_helper|raider_element|eventually|wait helper/i)
        end

        it 'documents the Appium locators and the waiting finds and actions' do
          section = section_of(readme)
          locators = section[/^### Locators\n.*?(?=^### )/m].gsub(/\s+/, ' ')
          expect(locators).to include('accessibility_id:', 'xpath:', 'id:', 'class_name:', 'find_elements')
          expect(section).to include('element(ios: { … }, android: { … })') if automation == 'cross_platform'
          waiting = section[/^### Waiting\n.*?(?=^### )/m].gsub(/\s+/, ' ')
          expect(waiting).to include('`find_element` and `find_elements` wait for a match',
                                     '`click`, `send_keys` and `clear` wait until the element is displayed and enabled',
                                     '`submit` is not checked', 'strict is off', 'force: true', 'Raider.actionability = false',
                                     'NotActionable', 'XCUITest', 'RAIDER_TIMEOUT', 'RAIDER_STRICT', 'RAIDER_ACTIONABILITY')
          expect(section[/^### Settings\n.*?(?=^### )/m]).to include('no `config/config.yml`') unless automation == 'cross_platform'
        end

        it 'documents the gestures and the assertions' do
          section = section_of(readme)
          gestures = section[/^### Gestures\n.*?(?=^### )/m].gsub(/\s+/, ' ')
          expect(gestures).to include("swipe('left', element)", "scroll('down')", 'scroll_to({ accessibility_id: ')
          expect(section[/^### Assertions\n.*?(?=^### )/m]).to include('have_text', 'expect { pdp_page.add_to_cart_button }')
        end

        it 'says the device capabilities sit under appium:options' do
          settings = section_of(readme)[/^### Settings\n.*?(?=^### )/m]
          expect(settings).to include('under `appium:options`')
          expect(settings).to include('under the `ios:` and `android:` parts') if automation == 'cross_platform'
        end
      end
    end
  end

  describe 'without example tests' do
    FRAMEWORKS.product(%w[selenium ios cross_platform]).each do |framework, automation|
      context "with #{framework} and #{automation}" do
        subject(:readme) { read_generated(ensure_project(framework:, automation:, examples: false), 'Readme.md') }

        it 'still explains how the framework works' do
          expect(readme).to include('## How the framework works', '### Locators', '### Assertions')
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

    FRAMEWORKS.each do |framework|
      it "shows how to add the login hook for the project's own login page in #{framework}" do
        readme = read_generated(ensure_project(framework:, automation: 'selenium', examples: false), 'Readme.md')
        section = readme[/^## Reusing the login\n.*?(?=^## )/m]
        hook = framework == 'rspec' ? 'config.before(:each, :logged_in) do' : "Before('@logged_in') do"
        expect(section).to include(hook, 'SessionState.new(driver).reuse(')
      end
    end
  end
end
