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

### Web Testing

| Test Framework | Selenium |
|----------------|----------|
| RSpec          | ✅       |
| Cucumber       | ✅       |

Watir was removed in ruby_raider 4.0; see [Migrating from Watir](#migrating-from-watir).

Existing projects pin `gem 'ruby_raider', '~> 3.15'` (or an older `~> 3.x`) in their Gemfile, so `bundle update` never moves them to 4.0; to upgrade, change the pin to `~> 4.0` and run `bundle update ruby_raider`.

### Mobile Testing (Appium)

| Test Framework | iOS | Android | Cross-Platform |
|----------------|-----|---------|----------------|
| RSpec          | ✅  | ✅      | ✅             |
| Cucumber       | ✅  | ✅      | ✅             |

### Optional Add-on (Web Only)

| Add-on | Flag | Description |
|--------|------|-------------|
| Accessibility | `--accessibility` | Adds axe gem + example accessibility tests |
| CI provider | `-p ci:azure` | Generates `azure-pipelines.yml` instead of the GitHub Actions workflow (default `ci:github`) |

This works on all platforms (Mac OS, Linux and Windows).

## What's Included

Every generated project comes with:

- **Page Object Model** — Base page and component classes with example pages
- **Test examples** — Working login tests against the [Raider Test Store](https://raider-test-site.onrender.com/)
- **Raider reporting** — RSpec and Cucumber projects include [raider_reporter](https://github.com/RaiderHQ/raider_reporter), which writes results to `raider-results/` and uploads runs to your Raider Hideout server when `RAIDER_TOKEN` and `RAIDER_ENDPOINT` are set; generated CI runs the suite through `raider-reporter exec` with `RAIDER_QUARANTINE`, so quarantined tests do not fail the build; an opt-in `raider-gate` job (`RAIDER_GATE=1`) fails CI when the Raider quality gate fails
- **Waiting** — generated Selenium and Appium projects wait for elements by themselves (`WaitHelper` and `RaiderElement`): `click`, `send_keys`, `text` and the rest poll until the element is ready, and `eventually { … }` retries assertions, so there is no implicit wait and no `sleep`; `timeout` in `config.yml` sets how long to wait
- **Example tests or a skeleton (`examples:false`)** — start from the working login examples, or pass `examples:false` for an empty skeleton with the helpers, config, CI and README (see [Getting Started](#getting-started))
- **Login reuse** — generated web projects (Selenium) log in once and restore the saved session for examples tagged `:logged_in` (RSpec) or `@logged_in` (Cucumber); `RAIDER_LOGIN_STATE=off|refresh` and `login_state: max_age:` control it, and the state stays in git-ignored `.raider/auth/`
- **Failure video replay** — Every test is recorded and the video is kept only for failing tests, attached to the report as `video` (WebM from page screenshots for Selenium, Appium's own MP4 for mobile, which needs `ffmpeg` on the Appium server host for iOS and for Android recordings over 180 s). Turn it off per run with `VIDEO=off`, or per project with `raider u video off`; ffmpeg is downloaded once, SHA-256 checked and cached in `~/.cache/raider`. The RaiderHQ `ffmpeg-7.1` build that the download uses is not published yet, so for now set `RAIDER_FFMPEG_PATH` to an ffmpeg with libvpx to get web videos
- **Failure trace replay** (Selenium with RSpec or Cucumber) — Failing tests keep a step-by-step trace: each action with its locator and wait time, a screenshot and the page HTML after every step that changes the page, plus network requests and console messages on Chrome, Edge and Firefox. It is saved as `raider-results/attachments/<n>-trace.zip`, attached to the report as `trace` and opened in Raider Desktop or on Hideout. `TRACE=on` keeps passing tests too, `TRACE=off` captures nothing, and `raider u trace on|off` sets it for the project. Typed values in password fields and `RAIDER_SECRET_*` values are hidden; other typed values, page text and URLs are kept, so treat a trace like the video. Request headers, cookies and bodies are never captured
- **Network mocking** (Selenium with RSpec or Cucumber) — Answer a request with your own response or block it, from the test: `mock_request('**/api/users', json: { users: [] })`, `mock_request(url, status: 500)` and `block_request('**/*.png')`, with `calls` to check what the page asked for. It uses WebDriver BiDi on Chrome, Edge and Firefox (Safari and `BIDI=off` raise `NetworkHelper::Unavailable`), handles CORS for cross-origin mocks, clears mocks after each test, and marks mocked requests in the trace
- **Screenshot comparison** (Selenium with RSpec or Cucumber) — `match_screenshot('home')` compares the page, or an element with `element:`, with a baseline in `screenshots/baselines/<browser>/`. The first run saves the baseline; later runs fail on a difference and attach the expected, actual and diff pictures to the report and the trace. `SCREENSHOTS=update` rewrites baselines, a missing baseline fails on CI, and tolerances (`threshold`, `max_diff_pixels`, `max_diff_ratio`) go in `config/config.yml` under `screenshots:`. Generate baselines where CI runs: a Retina laptop makes 2x pictures
- **GitHub Actions CI** — Ready-to-use test pipeline that caches ffmpeg for failure videos
- **Rake tasks** — Default, smoke, and regression tasks with tag-based filtering
- **Retry support** — RSpec retry with configurable retry count via `RETRY_COUNT` env var
- **Re-run failed tests** — RSpec keeps `spec/examples.txt` for `--only-failures`; Cucumber projects write failed scenarios to `rerun.txt`
- **Parallel execution** — parallel_tests and parallel_split_test gems included
- **Configurable browser** — Chrome/Firefox with customizable arguments, viewport, timeout, and headless mode
- **Linting** — RuboCop and Reek configs included

> **Upgrading from 3.9 or earlier:** existing projects are not changed automatically. To get failure videos, generate a
> new project with the same options and copy `helpers/video_helper.rb`, the video lines in `helpers/spec_helper.rb`
> (RSpec) or `features/support/env.rb` (Cucumber), the `listener:` in the driver helper, the `video:` block
> in `config/config.yml`, and the ffmpeg cache and install steps in your CI pipeline. raider_reporter 0.10 or later
> adds the inline video player in `raider-results/index.html` and a larger size limit for video attachments.

For Appium projects, download the example [app](https://github.com/RaiderHQ/raider_test_app) and start the server:

```bash
raider u start_appium
```

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

## Migrating from Watir

Watir was removed in ruby_raider 4.0. To move a Watir project to Selenium, generate a Selenium project and port your pages. The common mappings:

| Watir | Selenium project (waiting layer) |
|-------|----------------------------------|
| `browser.goto(url)` | `driver.navigate.to(url)` |
| `browser.text_field(id: 'x').set(v)` | `clear({ id: 'x' })` and `send_keys({ id: 'x' }, v)` |
| `browser.button(id: 'x').click` | `click({ id: 'x' })` |
| `Watir.default_timeout = n` | `timeout: n` in `config/config.yml` |

## Adopting waiting in an existing project

Gem upgrades do not rewrite generated code, so existing projects keep their implicit wait until you opt in:

1. Copy both `helpers/wait_helper.rb` and `helpers/raider_element.rb` from a freshly generated project into your
   `helpers/` folder. Keep them side by side: `wait_helper.rb` loads the other with `require_relative 'raider_element'`.
2. Include it in `Page`, the spec helper, or the World, after loading it with `require_relative`, for example
   `require_relative '../../helpers/wait_helper'` at the top of `page_objects/abstract/page.rb`.
3. Set how long it waits: add `timeout: 10` to `config/config.yml`. Single-platform mobile projects (iOS or Android
   only) have no `config/config.yml`, so pass `timeout:` to a call, or create `config/config.yml` with that line;
   without either, it waits 10 seconds.
4. Remove the `implicit_wait` line.
5. Move flaky spots to `click`, `send_keys` and `eventually` first.

Keep in mind that keeping the implicit wait while using the layer makes every `find` miss cost up to `timeout` seconds per poll cycle, so remove it once you have moved over.

## Adding network mocking to a 3.13 project

Gem upgrades do not rewrite generated code, so a project made with 3.13 or earlier opts in by hand (Selenium web projects only):

1. Copy `helpers/network_helper.rb` from a freshly generated project into your `helpers/` folder.
2. Load and include it: add `require_relative 'network_helper'` next to the other helper requires, then
   `config.include(NetworkHelper)` in `helpers/spec_helper.rb` (RSpec), or `World(NetworkHelper)` in
   `features/support/world.rb` with `require_relative '../../helpers/network_helper'` (Cucumber). If you want mocks in
   page objects, add `include NetworkHelper` to `page_objects/abstract/page.rb`.
3. In the after hook, call `mock_error = NetworkHelper.finish(driver)` before the driver quits. Treat the returned mock error
   as a failure when deciding whether to keep the trace and video (`example.exception || mock_error` in RSpec,
   `scenario.failed? || mock_error` in Cucumber), and `raise mock_error if mock_error` after the driver quits, so a failing
   mock block fails the test and mocks never leak into the next test.
4. In `helpers/driver_helper.rb`, make the BiDi condition include the helper:
   `bidi = (defined?(TraceHelper) && TraceHelper.bidi?(load_browser)) || (defined?(NetworkHelper) && NetworkHelper.bidi?(load_browser))`.

## Adding screenshot comparison to a 3.14 project

Gem upgrades do not rewrite generated code, so a project made with 3.14 or earlier opts in by hand (Selenium web projects only):

1. Copy `helpers/screenshot_helper.rb` from a freshly generated project into your `helpers/` folder, and add `gem 'chunky_png'` to the `Gemfile`.
2. Load and include it: add `require_relative 'screenshot_helper'` next to the other helper requires, then
   `config.include(ScreenshotHelper)` in `helpers/spec_helper.rb` (RSpec), or `World(ScreenshotHelper)` in
   `features/support/world.rb` with `require_relative '../../helpers/screenshot_helper'` (Cucumber). If you want it in
   page objects, add `include ScreenshotHelper` to `page_objects/abstract/page.rb`.
3. Call `ScreenshotHelper.reset` in the before hook, so a name can be used again in the next test.
4. Add the `screenshots:` block (`threshold`, `max_diff_pixels`, `max_diff_ratio`) from a fresh `config/config.yml`.
5. Use `raider_reporter` 0.14 or later to list comparisons in the report; with an older one the pictures are still attached.

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
raider g feature [NAME]         # Create a Cucumber feature
raider g steps [NAME]           # Create step definitions
raider g helper [NAME]          # Create a helper class
raider g component [NAME]       # Create a component class
raider g scaffold [NAME(S)]     # Create page + test + steps
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
