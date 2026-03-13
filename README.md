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
   <p align="center"> For more information and updates on releases, see <a href="https://ruby-raider.com">https://ruby-raider.com</a></p>
</div>

## What is Ruby Raider?

Ruby Raider is a CLI gem and API backend for scaffolding and generating UI test automation frameworks. It supports both interactive command-line usage and programmatic invocation via [Raider Desktop](https://ruby-raider.com).

## Supported Frameworks

### Web Testing

| Test Framework | Selenium | Watir | Capybara |
|----------------|----------|-------|----------|
| RSpec          | ✅       | ✅    | ✅       |
| Cucumber       | ✅       | ✅    | ✅       |
| Minitest       | ✅       | ✅    | ✅       |

### Mobile Testing (Appium)

| Test Framework | iOS | Android | Cross-Platform |
|----------------|-----|---------|----------------|
| RSpec          | ✅  | ✅      | ✅             |
| Cucumber       | ✅  | ✅      | ✅             |
| Minitest       | ✅  | ✅      | ✅             |

### Optional Add-ons (Web Only)

| Add-on | Flag | Description |
|--------|------|-------------|
| Accessibility | `--accessibility` | Adds axe gem + example accessibility tests |
| Visual Regression | `--visual` | Adds chunky_png + visual comparison helpers |
| Performance | `--performance` | Adds Lighthouse auditing (requires `npm install -g lighthouse`) |

### CI/CD Platforms

Projects can be generated with built-in CI/CD pipelines for **GitHub Actions** or **GitLab CI/CD**.

### Test Reporters

Choose a reporter with `--reporter`: `allure`, `junit`, `json`, `both`, `all`, or `none`.

***The web tests run against the [Raider Test Store](https://raider-test-site.onrender.com/).***

***To run Appium tests, download the example [app](https://github.com/RaiderHQ/raider_test_app) and start the server:***

```bash
raider u start_appium
```

This works on all platforms (Mac OS, Linux and Windows).

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

Add optional features:

```bash
raider new my_project -p framework:rspec automation:selenium --accessibility --visual --performance
```

Skip flags for leaner projects:

```bash
raider new my_project -p framework:cucumber automation:watir --skip_ci --skip_video --reporter none
```

## Commands

###### Anything between square brackets ([...]) is where your input goes

### Main Commands

```
raider new [PROJECT_NAME]       # Create a new framework project
raider adopt                    # Import an existing test project
raider generate                 # Access scaffolding commands
raider utility                  # Access utility commands
raider plugin_manager           # Manage plugins
raider version                  # Show current version
raider help [COMMAND]           # Describe available commands
```

Shortcuts: `n` (new), `a` (adopt), `g` (generate), `u` (utility), `pm` (plugin_manager), `v` (version)

### Scaffolding Commands

```
raider g page [NAME]            # Create a page object
raider g spec [NAME]            # Create an RSpec test
raider g feature [NAME]         # Create a Cucumber feature
raider g steps [NAME]           # Create step definitions
raider g helper [NAME]          # Create a helper class
raider g component [NAME]       # Create a component class
raider g scaffold [NAME(S)]     # Create page + test + steps
raider g destroy [NAME(S)]      # Delete scaffolded files
raider g from_url [URL]         # Generate page & spec from a live URL
```

Options:

* `--from [FILE]` — Generate spec from an existing page object
* `--ai` — Use LLM for intelligent test scenario generation
* `--dry_run` — Preview files without creating them
* `--uses [PAGES]` — Specify page dependencies
* `--path [PATH]` — Custom output path
* `--crud` — Generate full CRUD scaffold (list, create, detail, edit + tests)

### Utility Commands

```
raider u path [PATH]            # Set default paths for scaffolding
raider u url [URL]              # Set default project URL
raider u browser [BROWSER]      # Set default browser
raider u browser_options [OPTS] # Set browser options
raider u raid                   # Run all tests
raider u timeout [SECONDS]      # Set test timeout
raider u viewport [DIMENSIONS]  # Set viewport size (e.g., 1920x1080)
raider u platform [PLATFORM]    # Set platform for cross-platform tests
raider u debug [on/off]         # Toggle debug mode
raider u start_appium           # Start Appium server
raider u desktop                # Download Raider Desktop
raider u llm [PROVIDER]         # Configure LLM provider (openai, anthropic, ollama)
```

### Plugin Commands

```
raider pm add [NAME]            # Add a plugin to your project
raider pm delete [NAME]         # Remove a plugin
raider pm list                  # List available plugins
raider pm local                 # List installed plugins
```

### Adopt Command

Import an existing test project into Ruby Raider conventions:

```bash
raider adopt project [SOURCE_PATH]
```

## LLM Integration

Ruby Raider supports optional LLM-powered features for intelligent test generation. Configure a provider:

```bash
raider u llm openai      # Configure OpenAI
raider u llm anthropic   # Configure Anthropic
raider u llm ollama      # Configure Ollama (local, no API key needed)
```

Then use the `--ai` flag with scaffolding commands for smarter code generation.

## Development

```bash
bundle install          # Install dependencies
bundle exec rspec       # Run all tests
bundle exec rspec --tag ~slow  # Run fast tests only (skip E2E)
bundle exec rubocop     # Run linter
bundle exec reek        # Run code smell detection
```

## Links

* [RubyGems](https://rubygems.org/gems/ruby_raider)
* [GitHub](https://github.com/RubyRaider/ruby_raider)
* [Website](https://ruby-raider.com)
* [Community](https://gitter.im/RubyRaider/community)
