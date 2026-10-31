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

| Test Framework | Selenium | Watir |
|----------------|----------|-------|
| RSpec          | ✅       | ✅    |
| Cucumber       | ✅       | ✅    |

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
- **Login reuse** — generated web projects (Selenium or Watir) log in once and restore the saved session for examples tagged `:logged_in` (RSpec) or `@logged_in` (Cucumber); `RAIDER_LOGIN_STATE=off|refresh` and `login_state: max_age:` control it, and the state stays in git-ignored `.raider/auth/`
- **Failure video replay** — Every test is recorded and the video is kept only for failing tests, attached to the report as `video` (WebM from page screenshots for Selenium and Watir, Appium's own MP4 for mobile, which needs `ffmpeg` on the Appium server host for iOS and for Android recordings over 180 s). Turn it off per run with `VIDEO=off`, or per project with `raider u video off`; ffmpeg is downloaded once, SHA-256 checked and cached in `~/.cache/raider`. The RaiderHQ `ffmpeg-7.1` build that the download uses is not published yet, so for now set `RAIDER_FFMPEG_PATH` to an ffmpeg with libvpx to get web videos
- **GitHub Actions CI** — Ready-to-use test pipeline that caches ffmpeg for failure videos
- **Rake tasks** — Default, smoke, and regression tasks with tag-based filtering
- **Retry support** — RSpec retry with configurable retry count via `RETRY_COUNT` env var
- **Re-run failed tests** — RSpec keeps `spec/examples.txt` for `--only-failures`; Cucumber projects write failed scenarios to `rerun.txt`
- **Parallel execution** — parallel_tests and parallel_split_test gems included
- **Configurable browser** — Chrome/Firefox with customizable arguments, viewport, timeout, and headless mode
- **Linting** — RuboCop and Reek configs included

> **Upgrading from 3.9 or earlier:** existing projects are not changed automatically. To get failure videos, generate a
> new project with the same options and copy `helpers/video_helper.rb`, the video lines in `helpers/spec_helper.rb`
> (RSpec) or `features/support/env.rb` (Cucumber), the `listener:` in the driver or browser helper, the `video:` block
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
