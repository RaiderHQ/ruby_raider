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

### Flows: run without assertions (web)

A flow is a recorded chore with no checks, such as logging in and downloading a report. It is done when every step ran. Flows are RSpec files under `flows/`, so they use the same driver, locators, waiting, screenshots, video and trace as your tests.

```
raider flow init                     # adds flows/flow_helper.rb, flows/support/run.rb and .gitignore lines
raider flow run timesheet            # runs flows/timesheet_flow.rb headless
raider flow run timesheet --headed --retries 2 --input hours=7
raider flow list [--json]            # each flow and its last result
```

```ruby
# flows/timesheet_flow.rb
require_relative 'flow_helper'

RSpec.describe 'Fill the timesheet' do
  it 'saves the hours' do
    driver.navigate.to 'https://example.com/timesheet'
    driver.find_element(label: 'Hours').send_keys(flow_input('hours', '8'))
    driver.find_element(by_role('button', name: 'Save')).click
  end
end
```

- **Exit codes:** 0 completed, 1 a step failed, 2 setup failed (bundle, driver, missing helper), 3 the flow is already running. Each flow holds its own lock in `.raider/flows/`, and a second run exits 3 straight away.
- **Results:** each run gets its own `flow-results/<name>/<UTC time>/` (report, failure screenshot, video and trace), and `.raider/flows/<name>/runs.jsonl` gains one line: `started_at`, `finished_at`, `status` (`completed`, `failed`, `setup_error`, `busy`), `failed_step`, `attempt`, `trigger`, `results_dir`. The last 20 result folders and 50 lines are kept. Flow runs never touch `raider-results/`, and test runs never touch `flow-results/`.
- **Inputs:** `flow_input('name', 'default')` reads `--input name=value` (`RAIDER_INPUT_NAME`). Inputs show up in your shell history and process list, so keep secrets out of them.
- **Secrets:** put them in `.raider/flows/env` as `KEY=value` lines (`#` comments, no interpolation). The file is loaded only when you own it and it has permissions 600 (`chmod 600 .raider/flows/env`); otherwise the run warns and goes on without it. Values are never written to the run log (they are replaced with `[secret]`), but your flow's own output and errors are printed as they are. On Windows there are no permission bits, so the folder's access rules protect the file: keep the project in your user folder.
- **The same record every way:** `bundle exec rspec flows/timesheet_flow.rb` writes the same run log as `raider flow run`; `raider flow run` adds retries (whole flow, 30 s apart) and the exit codes. Set `RAIDER_FLOW_HEADED=1` to watch a plain rspec run (`headless: true` in `config/config.yml` still wins).
- Projects made with 4.0 can add flows: `raider flow init` raises the Gemfile's `ruby_raider` pin to `~> 4.1`; run `bundle install` after it.

### Scheduling flows

Your computer's own scheduler runs the flow, so nothing needs to stay open. Scheduling never asks for sudo or admin rights.

```bash
raider flow schedule timesheet --every weekday --at 17:30 --input hours=7 --notify
raider flow schedule backup --every hour --at :15
raider flow schedule report --every week --on fri --at 09:00 --retries 2
raider flow unschedule timesheet
raider flow schedules [--json]       # each schedule, its next run, last result and OS state
```

- **Rules:** `--every hour|day|weekday|week`. `--at HH:MM` (24h, local time) is required for `day`, `weekday` and `week`; for `hour` use `--at :MM` (default `:00`). `--on mon|tue|wed|thu|fri|sat|sun` is required for `week` and refused otherwise. `--retries N` (0 to 3) and `--input name=value` are passed to `raider flow run`. Scheduling a flow again replaces its schedule.
- **Schedulers:** macOS uses launchd (`~/Library/LaunchAgents/dev.rubyraider.flow.<hash>.<name>.plist`). Windows uses Task Scheduler (a task in the `\RubyRaider\` folder). Linux uses a systemd user timer in `~/.config/systemd/user`, or, when `systemctl --user` does not answer, one tagged line in your crontab. Times are local time (cron uses the system time zone).
- **Missed runs:** launchd runs a run missed while the Mac slept once on wake. Task Scheduler runs it as soon as it can. systemd (`Persistent=true`) runs it once your user manager is back, at the next boot or login. cron skips it, and `raider flow schedules` says so.
- **Logged in:** on macOS (a launchd agent in your GUI session) and Windows (a task that runs only while you are logged on) a run happens only while you are logged in.
- **Linux:** systemd user timers stop when you log out unless lingering is on: `loginctl enable-linger $USER` (raider does not run it). A systemd schedule can only be removed from a session where `systemctl --user` works; until then `unschedule` refuses and keeps the entry.
- **Per machine:** schedules live in `.raider/flows/schedules.yml`, which `raider flow init` git-ignores, so a fresh clone has none. schedules.yml is the source of truth, and the next run is worked out from the rule. Each OS entry is tied to the project's path: unschedule before you move the project.
- **States:** `ok`, `missing from launchd` (or `Task Scheduler`, `systemd`, `cron`) when the OS entry is gone, `missing from schedules.yml` when the OS still runs a flow the file does not list, `Ruby not found: re-schedule`, `flow not found: unschedule` when `flows/<name>_flow.rb` was deleted or renamed, and `unknown (...)` when the scheduler could not be asked.
- **Ruby:** the OS entry runs the absolute `ruby` and `bundle` paths captured when you scheduled, plus `GEM_HOME` and `GEM_PATH` on macOS and Linux. After a Ruby upgrade or move, `schedules` says `Ruby not found: re-schedule`: run `raider flow schedule` again.
- **Logs:** on macOS and Linux the scheduler's output goes to `.raider/flows/<name>/scheduler.log`. Windows tasks run ruby.exe directly with your user environment and keep no scheduler.log; each run's result is in `runs.jsonl` as always.
- **Notify:** `--notify` shows a desktop notification only when a run ends failed or could not start (not when it completed, was already running, or was stopped). macOS uses `osascript`, Linux `notify-send`, Windows a PowerShell toast. When a run could not start, the notification points at `.raider/flows/<name>/scheduler.log` for a scheduled run on macOS and Linux, and at the run output otherwise. A notification that can't be shown prints a warning and never changes the exit code. On Linux `notify-send` needs your desktop session bus: under cron, and in a systemd user session that has not imported it, it usually can't show, and only the warning lands in scheduler.log. `raider flow run --notify` does the same for a manual run.
- **Secrets:** keep them in `.raider/flows/env`, never in `--input`: inputs are stored in plain text in the OS entry and in schedules.yml.
- **Windows refusals:** Task Scheduler expands `%NAME%` with no way to escape it, so an input or path holding `%...%` is refused. An argument holding both `'` and one of `* ? [ {` is refused too, because ruby.exe would glob it.
- **Tested on:** macOS (launchd) is tested against the real scheduler. Task Scheduler, systemd and cron are covered by unit tests with a fake scheduler only.

### Scheduling tests

Your computer's own scheduler runs the project's tests: all of them, one tag, or a list of spec files. Nothing needs to stay open, and scheduling never asks for sudo or admin rights. `raider sc` is short for `raider schedule`.

```bash
raider schedule add nightly --every day --at 02:00 --notify
raider schedule add smoke --every hour --at :15 --tag smoke --retries 1
raider schedule add checkout spec/cart_spec.rb spec/checkout_spec.rb --every weekday --at 08:30 --show-browser
raider schedule add weekly --every week --on fri --at 18:00 --project ~/code/my_tests
raider schedule list [--json]        # each schedule, its next run, last result and OS state
raider schedule run nightly          # run it now, the way the scheduler does
raider schedule remove nightly
```

- **Rules:** `--every hour|day|weekday|week`. `--at HH:MM` (24h, local time) is required for `day`, `weekday` and `week`; for `hour` use `--at :MM` (default `:00`). `--on mon|tue|wed|thu|fri|sat|sun` is required for `week` and refused otherwise. Names use 1 to 60 of `a-z`, `0-9` and `_`. Adding a name again replaces its schedule.
- **What runs:** no files and no `--tag` runs all tests. `--tag TAG` runs one tag (letters, digits, `_`, `:` and `-`). Spec files are relative paths inside the project ending in `_spec.rb`, at most 200, and they can go before or after the options. `--tag` and files can't be used together.
- **`--project PATH`:** works from any folder. Put it after the subcommand (`raider schedule add nightly ... --project DIR`); before the subcommand Thor shows the help instead.
- **Per machine:** schedules live in `.raider/schedules/schedules.yml`, which `add` git-ignores (it holds machine paths), so a fresh clone has none. The OS entry holds only the schedule's name: `raider schedule run NAME --project DIR --trigger schedule`. The selection, retries, notify and show-the-browser setting are read from schedules.yml at each run, which checks every entry again before anything starts.
- **Show the browser:** scheduled runs are hidden (`HEADLESS=true`) unless you add `--show-browser`. It shows the browser whatever `headless` says in `config/config.yml`, and no driver change is needed: the runtime handles it (`RAIDER_SHOW_BROWSER=1` drops `--headless`). Neither config.yml nor `helpers/driver_helper.rb` is written.

| Project Headless (config.yml) | Show the browser off | Show the browser on |
|---|---|---|
| off / absent | `HEADLESS=true`: hidden | `RAIDER_SHOW_BROWSER=1`, `HEADLESS` removed: visible |
| on | `HEADLESS=true`: hidden | `RAIDER_SHOW_BROWSER=1`: visible (the runtime drops `--headless`) |

- **Where a browser can show:** on macOS while you are logged in (a launchd agent runs in your GUI session). On Windows the task runs in your session while you are logged on; a visible browser there is not verified yet. On Linux `--show-browser` is refused ("Show the browser isn't available for scheduled runs on Linux"): systemd user units and cron have no display. A project made before 4.0 is refused too ("Show the browser needs a project made with Ruby Raider 4.0 or later").
- **Retries:** `--retries N` (0 to 3) re-runs each failed test up to N times inside the same run, with rspec-retry (`RETRY_COUNT` is N + 1). From 4.2 the runtime gives a retried test a fresh browser. Before 4.2, a retry in a generated project failed with a refused connection, because the driver was already quit. The fix is in the gem (`ruby_raider/runtime/rspec`), so it also applies to manual runs such as `RETRY_COUNT=2 bundle exec rspec`; `bundle update ruby_raider` brings it to existing projects.
- **Results:** a run is a normal `bundle exec rspec`, so its report goes to `raider-results/` and shows on the Dashboard. Each run also adds one line to `.raider/schedules/<name>/runs.jsonl` (`status` `passed`, `failed`, `setup_error` or `busy`, the counts and the trigger; the last 50 lines are kept), and the last report is copied to `.raider/schedules/<name>/last/` (run.json and index.html, plus the attachments when they come to 50 MB or less).
- **Exit codes:** `raider schedule run` exits 0 passed, 1 failed, 2 could not start or refused, 3 another scheduled run was going. Only one scheduled run per project goes at a time, and a busy run leaves `raider-results/` alone. Other commands exit 0, or 2 with one line on stderr. Thor's own usage errors (a missing NAME, a bad `--retries`) exit 1 with Thor's text.
- **Notify:** `--notify` shows a desktop notification only when a run failed or could not start (not when it passed, was busy or was stopped). The title is "Ruby Raider: <name> failed"; the body says how many tests failed, or why the run could not start. macOS uses `osascript`, Linux `notify-send`, Windows a PowerShell toast. A notification that can't be shown prints a warning and never changes the exit code. On Linux `notify-send` needs your desktop session bus, so under cron, and in a systemd user session that has not imported it, it usually can't show.
- **Schedulers:** macOS uses launchd (`~/Library/LaunchAgents/dev.rubyraider.schedule.<hash>.<name>.plist`). Windows uses Task Scheduler (a task in the `\RubyRaider\` folder). Linux uses a systemd user timer in `~/.config/systemd/user`, or, when `systemctl --user` does not answer, one tagged line in your crontab. Times are local time (cron uses the system time zone).
- **Missed runs:** launchd runs a run missed while the Mac slept once on wake. Task Scheduler runs it as soon as it can. systemd (`Persistent=true`) runs it once your user manager is back, at the next boot or login. cron skips it, and `raider schedule list` says so.
- **Logged in:** on macOS and Windows a run happens only while you are logged in. On Linux, systemd user timers stop when you log out unless lingering is on: `loginctl enable-linger $USER` (raider does not run it). A systemd schedule can only be removed from a session where `systemctl --user` works; until then `remove` refuses and keeps the entry.
- **States:** `ok`, `missing from launchd` (or `Task Scheduler`, `systemd`, `cron`) when the OS entry is gone, `missing from schedules.yml` when the OS still runs a schedule the file does not list, `Ruby not found: re-schedule`, `test file not found: <file>` when a listed spec file was deleted or renamed, and `unknown (...)` when the scheduler could not be asked.
- **Ruby:** the OS entry runs the absolute `ruby` and `bundle` paths captured when you added it, plus `GEM_HOME` and `GEM_PATH` on macOS and Linux. After a Ruby upgrade or move, run `raider schedule add` again.
- **Logs:** on macOS and Linux the scheduler's output goes to `.raider/schedules/<name>/scheduler.log`, moved to `scheduler.log.1` at the start of a scheduled run once it is over 1 MB. Windows tasks keep no scheduler.log; each run's result is in `runs.jsonl` as always.
- **Windows refusals:** Task Scheduler and ruby.exe would expand `%...%`, `*`, `?`, `[` or `{`, so a spec file or path holding them is refused: rename the file or use a tag.
- **Moving the project:** each OS entry is tied to the project's path (`<hash>` is made from it). Run `raider schedule remove` before you move the project. Entries made before a move keep the old path's id, so `list` in the new place can't find them. Remove them by hand; their names start with `dev.rubyraider.schedule.`:
  - macOS: `launchctl bootout gui/$UID/<label>`, then delete `~/Library/LaunchAgents/<label>.plist`.
  - Windows: `schtasks /Delete /TN \RubyRaider\<id> /F`.
  - Linux (systemd): `systemctl --user disable --now <id>.timer`, delete `<id>.timer` and `<id>.service` from `~/.config/systemd/user`, then `systemctl --user daemon-reload`.
  - Linux (cron): `crontab -e` and delete the `# raider-schedule <id>` line and the line under it.
- **Tested on:** macOS (launchd) is tested against the real scheduler: adding, a run started by launchd hidden and shown with Headless on, a failed run with a notification, a busy run, and removing. Task Scheduler, systemd and cron are covered by unit tests with a fake scheduler only.

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
raider flow                     # Run flows: init, run, list, schedule
raider schedule                 # Schedule the tests: add, list, remove, run
raider version                  # Show current version
raider help [COMMAND]           # Describe available commands
```

Shortcuts: `n` (new), `g` (generate), `u` (utility), `f` (flow), `sc` (schedule), `v` (version)

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
