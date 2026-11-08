# Ruby Raider

[![Gem Version](https://badge.fury.io/rb/ruby_raider.svg)](https://badge.fury.io/rb/ruby_raider)
[![Tests](https://github.com/RubyRaider/ruby_raider/actions/workflows/integration.yml/badge.svg)](https://github.com/RubyRaider/ruby_raider/actions/workflows/integration.yml)
[![Reek](https://github.com/RubyRaider/ruby_raider/actions/workflows/reek.yml/badge.svg)](https://github.com/RubyRaider/ruby_raider/actions/workflows/reek.yml)
[![Rubocop](https://github.com/RubyRaider/ruby_raider/actions/workflows/rubocop.yml/badge.svg)](https://github.com/RubyRaider/ruby_raider/actions/workflows/rubocop.yml)
[![Gitter](https://badges.gitter.im/RubyRaider/community.svg)](https://gitter.im/RubyRaider/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

<!-- PROJECT LOGO -->
<br />
<div align="center">
   <a href="https://github.com/RubyRaider/ruby_raider">
   <img src="assets/ruby_raider_logo.svg" alt="Logo" style="width:200px;">
   </a>
   <p align="center">
      <a href="https://github.com/RubyRaider/ruby_raider#getting-started"><strong>Explore the docs</strong></a>
      <br />
      <br />
      <a href="https://rubygems.org/gems/ruby_raider">Rubygems</a>
      ·
      <a href="https://github.com/RubyRaider/ruby_raider/issues">Report Bug</a>
      ·
      <a href="https://github.com/RubyRaider/ruby_raider/issues">Request Feature</a>
   </p>
   <p align="center"> For more information and updates on releases, see https://ruby-raider.onrender.com/</p>
</div>

## What is Ruby Raider?

Ruby Raider is a CLI gem for scaffolding and generating UI test automation frameworks. It supports interactive command-line usage and flag-driven invocation (for example `raider new my_project -p framework:rspec automation:selenium`), which is how [Raider Desktop](https://ruby-raider.com) drives it.

## Supported Frameworks

Ruby Raider works on Mac OS, Linux and Windows.

### Web Testing

Web projects use **Selenium and RSpec**. They get:

- Locators people see on the page (`label:`, `text:`, `by_role(...)` and more), with strict matching
- Automatic waiting for elements and actions: no implicit wait, no `sleep`
- Retrying RSpec matchers
- Login reuse, failure video, failure trace, network mocking and screenshot comparison
- Optional accessibility tests (axe) and a choice of GitHub Actions or Azure Pipelines

See [What's Included](#whats-included) for each one.

### Mobile Testing

Mobile projects use **Appium and RSpec**:

| Test Framework | iOS | Android | Cross-Platform |
|----------------|-----|---------|----------------|
| RSpec          | ✅  | ✅      | ✅             |

They get:

- Appium locators: `accessibility_id:`, `id:`, `xpath:` and `class_name:`
- Automatic waiting: `find_element` waits for a match, and `click`, `send_keys` and `clear` wait until the element is displayed and enabled
- Retrying RSpec matchers
- Gestures: `swipe`, `scroll` and `scroll_to`, on iOS and Android
- Failure video from Appium's screen recording
- Raider reporting and a GitHub Actions workflow that starts a simulator or emulator and Appium

On native app screens, `find_element` returns the first match (strict matching is web only) and `submit` is not checked.

To run the examples, download the example [app](https://github.com/RaiderHQ/raider_test_app) and start the server:

```bash
raider u start_appium
```

### Optional Add-ons

| Add-on | Flag | Description |
|--------|------|-------------|
| Accessibility (web) | `--accessibility` | Adds the axe gem and example accessibility tests |
| CI provider (web) | `-p ci:azure` | Generates `azure-pipelines.yml` instead of the GitHub Actions workflow (default `ci:github`) |

## What's Included

Every generated project loads the Raider runtime (`ruby_raider/runtime`). It adds locators, waiting and assertions to Selenium and Appium themselves.

### Locators

Find elements the way a person sees them, on top of Selenium's `id:`, `css:`, `xpath:`, `name:`, `class:` and `link_text:`:

| Key | Finds |
|-----|-------|
| `label:` | the field with that label, `aria-label` or `aria-labelledby` |
| `placeholder:` | the field with that placeholder |
| `alt:` | the element with that `alt` text |
| `title:` | the element with that `title` |
| `text:` | the innermost element whose text contains it |
| `test_id:` | the element whose `data-testid` equals it |
| `by_role(...)` | the element with that ARIA role and name |

```ruby
driver.find_element(label: 'Email')
driver.find_element(label: ['Email', { exact: true }])   # whole text only
driver.find_element(by_role('button', name: 'Save'))
driver.find_element(by_role('heading', level: 1))
```

- Text keys match part of the text and ignore extra spaces. Pass `{ exact: true }` for the whole text.
- `test_id:` reads another attribute with `Raider.test_id_attribute = 'data-qa'` or `RAIDER_TEST_ID_ATTRIBUTE`.
- **Strict matching:** `find_element` fails with `Raider::AmbiguousMatch` when a locator matches more than one element. `find_elements` never does. Turn it off with `raider u strict off`.

These keys are for web pages. Mobile projects use Appium's locators (see [Mobile Testing](#mobile-testing)).

### Waiting and actionability

- `find_element` and `find_elements` wait for a match. There is no implicit wait and no `sleep`.
- Before an action, the runtime waits until the element is ready:

| Action | Waits until the element is |
|--------|----------------------------|
| `click` | visible, enabled, not inert, stable and not covered |
| `send_keys`, `clear` | visible, enabled, editable and not inert |
| `submit` | visible, enabled and not inert |

- `force: true` skips the checks for one call: `button.click(force: true)`.
- Set the rules with `timeout`, `strict` and `actionability` in `config/config.yml`, or `RAIDER_TIMEOUT`, `RAIDER_STRICT` and `RAIDER_ACTIONABILITY`.

### Assertions

RSpec matchers retry until the page matches or `timeout` runs out:

`have_text`, `have_value`, `have_attribute`, `have_css`, `have_xpath`, `have_element`, `have_count`, `have_title`, `have_url`, `be_visible`, `be_hidden`, `be_enabled`, `be_disabled`, `be_checked`

```ruby
expect { account_page.welcome_message }.to have_text('Welcome')
expect { driver.find_element(id: 'status').text }.to eq('done')   # any value matcher retries in a block
```

### Raider reporting

Projects include [raider_reporter](https://github.com/RaiderHQ/raider_reporter).

- Results go to `raider-results/`.
- Runs upload to your Raider Hideout server when `RAIDER_TOKEN` and `RAIDER_ENDPOINT` are set.
- CI runs the suite through `raider-reporter exec` with `RAIDER_QUARANTINE`, so quarantined tests do not fail the build.
- Set the CI variable `RAIDER_GATE` to `1` to add a `raider-gate` job that fails CI when the Raider quality gate fails.

### Failure video replay

Each test is recorded. The video is kept only when the test fails and attached to the report as `video`.

- **Web:** WebM built from page screenshots. ffmpeg is downloaded once, SHA-256 checked and cached in `~/.cache/raider`: an LGPL ffmpeg 7.1 build with libvpx for macOS (Apple silicon and Intel), Linux x64 and Windows x64, built by [`.github/workflows/ffmpeg.yml`](.github/workflows/ffmpeg.yml). On other platforms set `RAIDER_FFMPEG_PATH` to an ffmpeg with libvpx.
- **Mobile:** Appium's own MP4. iOS needs `ffmpeg` on the Appium server host. Android stops at 180 s by default, so it needs no ffmpeg; a longer `video.time_limit` needs ffmpeg too.
- Turn it off per run with `VIDEO=off`, or per project with `raider u video off`.

### Failure trace replay (web)

Failing tests keep a step-by-step trace:

- each action with its locator and wait time
- a screenshot and the page HTML after every step that changes the page
- network requests and console messages on Chrome, Edge and Firefox

It is saved as `raider-results/attachments/<n>-trace.zip`, attached to the report as `trace`, and opens in [Raider Desktop](https://ruby-raider.com) or on Hideout.

- `TRACE=on` keeps passing tests too. `TRACE=off` captures nothing. `raider u trace on|off` sets it for the project.
- Password fields and `RAIDER_SECRET_*` values are hidden. Other typed values, page text and URLs are kept, so treat a trace like the video.
- Request headers, cookies and bodies are never captured.

### Network mocking (web)

Answer a request with your own response, or block it:

```ruby
mock_request('**/api/users', json: { users: [] })
mock_request(url, status: 500)
block_request('**/*.png')
```

- `mock_request` returns the mock; `mock.calls` lists the requests it answered.
- Works through WebDriver BiDi on Chrome, Edge and Firefox. Safari and `BIDI=off` raise `NetworkHelper::Unavailable`.
- Handles CORS for cross-origin mocks, clears mocks after each test, and marks mocked requests in the trace.

### Screenshot comparison (web)

```ruby
match_screenshot('home')
```

- Compares the page, or one element with `element:`, with a baseline in `screenshots/baselines/<browser>/`.
- The first run saves the baseline. Later runs fail on a difference and attach the expected, actual and diff pictures to the report and the trace.
- `SCREENSHOTS=update` rewrites baselines. A missing baseline fails on CI.
- Tolerances (`threshold`, `max_diff_pixels`, `max_diff_ratio`) go in `config/config.yml` under `screenshots:`.
- Generate baselines where CI runs: a Retina laptop makes 2x pictures.

### Login reuse (web)

Example projects log in once and restore the saved session for examples tagged `:logged_in`.

- `RAIDER_LOGIN_STATE=off|refresh` and `login_state: max_age:` control it.
- The state stays in git-ignored `.raider/auth/`.
- Skeletons (`examples:false`) get `SessionState#reuse` to wire your own login.

### Also included

- **Page Object Model:** base page and component classes with example pages
- **Example tests:** working tests against the [Raider Test Store](https://raider-test-site.onrender.com/) (web) or the [Raider test app](https://github.com/RaiderHQ/raider_test_app) (mobile), or an empty skeleton with `examples:false` (see [Getting Started](#getting-started))
- **CI:** GitHub Actions, or Azure Pipelines for web. It caches ffmpeg and comments results on pull requests
- **Failure screenshots:** each failing test attaches a screenshot to the report
- **Rake tasks:** default, smoke and regression, filtered by tag
- **Retries:** RSpec retry, with the count set by `RETRY_COUNT`
- **Re-run failed tests:** RSpec keeps `spec/examples.txt` for `--only-failures`
- **Parallel execution:** `parallel_tests` and `parallel_split_test`
- **Configurable browser:** Chrome or Firefox, with arguments, viewport, timeout and headless mode
- **Linting:** RuboCop and Reek configs

## Getting Started

Install the gem:

```bash
gem install ruby_raider
```

Create a new project interactively:

```bash
raider new [project_name]
```

Or skip the menu with parameters:

```bash
raider new [project_name] -p framework:rspec automation:selenium
```

Create a mobile project (`automation:ios`, `automation:android` or `automation:cross_platform`):

```bash
raider new my_app -p framework:rspec automation:android
```

Add accessibility testing:

```bash
raider new my_project -p framework:rspec automation:selenium --accessibility
```

Generate an Azure Pipelines file instead of GitHub Actions (web projects only):

```bash
raider new my_project -p framework:rspec automation:selenium ci:azure
```

Azure Pipelines for mobile (Appium) projects is not available yet: with `ci:azure` no pipeline file is generated and a notice is printed.
Azure Repos ignores `pr:` triggers, so add the pipeline as a Build validation branch policy to get pull request builds.

Generate an empty skeleton, without the example pages and tests (the menu asks `Do you want example tests?`):

```bash
raider new my_project -p framework:rspec automation:selenium examples:false
```

The skeleton keeps the helpers, config, CI and README, and its empty suite passes; grow it with `raider g`.

## Commands

###### Anything between square brackets ([...]) is where your input goes

### Main Commands

```
raider new [PROJECT_NAME]       # Create a new framework project
raider generate                 # Access scaffolding commands
raider utility                  # Access utility commands
raider version                  # Show current version
raider help [COMMAND]           # Describe available commands
```

Shortcuts: `n` (new), `g` (generate), `u` (utility), `v` (version)

### Scaffolding Commands

```
raider g page [NAME]            # Create a page object
raider g spec [NAME]            # Create an RSpec test
raider g helper [NAME]          # Create a helper class
raider g component [NAME]       # Create a component class
raider g scaffold [NAME(S)]     # Create page + spec
```

Options:

* `--path [PATH]` — Custom output path

### Utility Commands

```
raider u path [PATH]            # Set default paths for scaffolding
raider u url [URL]              # Set default project URL
raider u browser [BROWSER]      # Set default browser
raider u browser_options [OPTS] # Set browser arguments (e.g., no-sandbox, headless)
raider u headless [on/off]      # Toggle headless mode
raider u strict [on/off]        # Toggle strict find_element (fail on multiple matches)
raider u actionability [on/off] # Toggle the actionability wait before element actions
raider u raid                   # Run all tests (-p for parallel)
raider u timeout [SECONDS]      # Set test timeout
raider u viewport [DIMENSIONS]  # Set viewport size (e.g., 1920x1080)
raider u platform [PLATFORM]    # Set platform for cross-platform tests
raider u start_appium           # Start Appium server
raider u desktop                # Download Raider Desktop
raider u video [ACTION]         # Failure videos: install (ffmpeg), status, on, off
raider u trace [on/off]         # Failure traces: turn on or off (Selenium)
```

## Development

```bash
bundle install          # Install dependencies
bundle exec rspec       # Run all tests
bundle exec rspec --tag ~slow  # Run fast tests only (skip E2E)
bundle exec rubocop     # Run linter
bundle exec reek        # Run code smell detection
```

### Security checks

```bash
bundle exec bundler-audit check --update  # Check gems for known vulnerabilities
bundle exec ruby-audit check              # Check Ruby and RubyGems versions for known vulnerabilities
bundle exec rubocop --only Security       # Run RuboCop's Security cops
```

The same checks (plus OSV-Scanner) run in CI via `.github/workflows/security.yml`.

## Links

* [RubyGems](https://rubygems.org/gems/ruby_raider)
* [GitHub](https://github.com/RubyRaider/ruby_raider)
* [Website](https://ruby-raider.onrender.com/)
* [Community](https://gitter.im/RubyRaider/community)
