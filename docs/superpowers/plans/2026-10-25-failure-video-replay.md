# Failure Video Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every failing test in a newly generated Raider project gets a WebM (web) or MP4 (Appium) replay that plays inline in the raider_reporter HTML report and in raider_desktop. Nothing has to be installed by hand.

**Architecture:** The ruby_raider gem gets a pinned, checksum-verified ffmpeg downloader (`RubyRaider::Ffmpeg`). Generated projects get a revived `VideoHelper`: it captures page screenshots on an interval and encodes them to VP8 WebM only when the test fails. Appium projects use Appium's own recorder. raider_reporter gets a separate video size cap, upload ordering that puts screenshots first, and a `<video>` player. raider_desktop gets a scoped `raider-media://` protocol and a player in the result card.

**Tech Stack:** Ruby 3.2+ (ruby_raider, raider_reporter, RSpec), Selenium WebDriver / Watir / appium_lib in generated projects, LGPL ffmpeg with libvpx, Electron + React + Vitest (raider_desktop).

**Spec:** `docs/superpowers/specs/2026-10-25-failure-video-replay-design.md` (ruby_raider repo). Read it before starting any task.

**Repos and branches:**

| Repo | Base | Branch | Release |
|---|---|---|---|
| `~/ruby_raider` | `origin/master` (3.9.0) | `feat/failure-video-replay` (exists, spec committed) | 3.10.0 |
| `~/raider_reporter` | `main` (0.9.0) | `feature/video-attachments` | 0.10.0 |
| `~/raider_desktop` | `origin/master` (3.6.0) | `feature/video-player` | 3.7.0 |

Order: Task 1 (spike) gates everything. Then raider_reporter (Tasks 2–4), ruby_raider (5–9), raider_desktop (10–11). Desktop does not depend on ruby_raider and can run in parallel with Tasks 5–9.

## Global Constraints

- Video is on by default in new projects: `video.enabled: true` in generated `config/config.yml`. `VIDEO=off` disables it for one run.
- Keep the replay only when the test fails. Passing tests pay the capture cost but not the encode cost.
- ffmpeg resolution order is `RAIDER_FFMPEG_PATH`, then the cached pinned binary, then a download. A system `ffmpeg` on PATH is never used unless `RAIDER_FFMPEG_PATH` points to it.
- Cache path: `~/.cache/raider/ffmpeg/<version>/ffmpeg[.exe]`, or `%LOCALAPPDATA%\raider\ffmpeg\<version>\` on Windows. `RAIDER_CACHE_DIR` overrides the root.
- Download: HTTPS only. Verify SHA-256 before an atomic rename and `chmod +x`. On a mismatch, delete the file, warn, and record no video. Never query "latest".
- Platforms: `darwin-arm64`, `darwin-x64`, `linux-x64`, `windows-x64`.
- Web output is WebM/VP8. Appium output is the MP4 that Appium returns, not re-encoded.
- Config block (web and mobile): `video: { enabled: true, fps: 5, max_width: 1280 }`.
- raider_reporter: `max_video_bytes` defaults to 50 MB (`50 * 1024 * 1024`) for `video/*`. `max_attachment_bytes` stays at 5 MB for everything else.
- Upload budget is unchanged: 45 MB and 1000 files. Non-video attachments go first, then videos fill whatever room is left.
- Desktop serves media only through `raider-media://` and only from `<abs>/raider-results/attachments(-N)?/<file>`. No general `file://` access.
- Recording must never raise into a test or change its result or exit code. After the first error: one `[video]` warning, then recording is disabled for the rest of the process.
- Slowdown limit: under 15% added wall time on the generated sample suite compared with `VIDEO=off`. If it's missed, **stop and ask the user**; do not choose a trade-off.
- The `ffmpeg-<version>` release is not published yet. Build against a placeholder manifest (`sha256: nil`). With the placeholder, `ensure!` warns `ffmpeg build not published yet` and returns nil.

## Review Focus

1. **Odd or long test names, and two processes running at once:** names with `/`, quotes or emoji, or two parallel_tests processes running the same test name, must not collide or break paths. Use a per-test `Dir.mktmpdir`; the name only goes into the attachment label. *(Task 7 test.)*
2. **Driver dies before the after hook:** the session crashed or `quit` already ran, so `stop` must return nil, warn once, and not raise. *(Task 7 test.)*
3. **First run with parallel_tests:** N processes start the ffmpeg download at the same moment. Exactly one binary ends up in the cache, it's valid, and no process sees a partial file. *(Task 5 test.)*
4. **Encoding fails:** ffmpeg exits non-zero or produces a 0-byte file. No attachment, one warning, the test result is unchanged. *(Task 7 test.)*
5. **Video over the cap:** a 60 MB video is rejected with a warning, and the screenshot on the same test is still attached. *(Task 2 test.)*

---

### Task 1: Spike — background capture safety and cost (gate)

Throwaway. The goal is a decision recorded in the spec, not code to keep.

**Files:**
- Create (scratch, not committed): a generated project via `bin/raider new spike -p framework:rspec automation:selenium` and a `spike_recorder.rb` inside it
- Modify: `docs/superpowers/specs/2026-10-25-failure-video-replay-design.md` (append a "Spike result" section)

**Interfaces:**
- Produces: `CAPTURE_MODE`, either `:thread` (background thread calling `save_screenshot` every `1.0/fps` s) or `:listener` (capture after each driver command through a `Selenium::WebDriver::Support::AbstractEventListener`). Task 7 implements the chosen one.

- [ ] **Step 1:** In the spike project, run a background thread that calls `driver.save_screenshot` every 200 ms while the sample suite runs, for headless Chrome, headed Chrome and Firefox. Run each 20 times.
  Pass: zero `Net::ReadTimeout`, `Errno::*`, `Selenium::WebDriver::Error::*` or garbled-response errors that are absent in a `VIDEO=off` run.
- [ ] **Step 2:** Measure wall time for each browser (median of 5 runs) with capture on and off.
- [ ] **Step 3:** If the thread approach fails Step 1 or goes over 15% in Step 2, repeat both steps with listener capture (frames after `navigate_to`, `click`, `change_value` and `execute_script`, plus one final frame).
- [ ] **Step 4:** Append to the spec: chosen `CAPTURE_MODE`, error counts, and median slowdown per browser. **If neither approach is under 15%, stop and ask the user which gives way (the limit, the fps, or default-on for that browser). Do not continue.**
- [ ] **Step 5: Commit**
```bash
git add docs/superpowers/specs/2026-10-25-failure-video-replay-design.md
git commit -m "Record video capture spike result"
```

---

### Task 2: raider_reporter — separate size cap for video

**Files:**
- Modify: `lib/raider_reporter/configuration.rb:9-20`
- Modify: `lib/raider_reporter.rb:48-56` (`start_collector!`) and `:63-84` (`attach`)
- Modify: `lib/raider_reporter/collector.rb:11-13,115-125` (`keep?`)
- Test: `spec/raider_reporter/attach_spec.rb`, `spec/raider_reporter/configuration_spec.rb`

**Interfaces:**
- Produces: `Configuration#max_video_bytes` (Integer, default `50 * 1024 * 1024`); `Collector.new(max_attachment_bytes:, max_video_bytes:, ...)`; `RaiderReporter.attachment_limit(content_type) -> Integer` (private helper, `video/*` → video cap, else attachment cap).

- [ ] **Step 1: Write the failing tests**
```ruby
# configuration_spec.rb
it "defaults max_video_bytes to 50 MB" do
  expect(described_class.new({}).max_video_bytes).to eq(50 * 1024 * 1024)
end

# attach_spec.rb
it "accepts a video larger than max_attachment_bytes but within max_video_bytes" do
  RaiderReporter.configuration.max_attachment_bytes = 3
  RaiderReporter.configuration.max_video_bytes = 10
  # start collector/run/test as in the existing specs; write "fivebytes" to clip.webm
  expect(RaiderReporter.attach("video", path, type: :webm)).to be(true)
  expect(finish(collector).attachments.map(&:content_type)).to eq(["video/webm"])
end

it "rejects a video over max_video_bytes and keeps the screenshot on the same test" do
  RaiderReporter.configuration.max_video_bytes = 3
  # attach shot.png (2 bytes, type: :png) then clip.webm (4 bytes, type: :webm)
  expect(RaiderReporter.attach("video", video_path, type: :webm)).to be(false)
  expect(err.string).to include("clip.webm").and include("larger than 3 bytes")
  expect(finish(collector).attachments.map(&:name)).to eq(["screenshot"])
end
```
- [ ] **Step 2:** Run `bundle exec rspec spec/raider_reporter/attach_spec.rb spec/raider_reporter/configuration_spec.rb`. Expected: FAIL (`undefined method max_video_bytes`).
- [ ] **Step 3:** Add `max_video_bytes`. Resolve the content type once in `attach` (before the size check) and compare against the limit for that type. Pass `max_video_bytes:` into `Collector`, and make `keep?` choose its limit from `attachment.content_type`.
- [ ] **Step 4:** Run the same command, then `bundle exec rspec`. Expected: all PASS.
- [ ] **Step 5: Commit** `git commit -am "Give video attachments their own 50 MB size cap"`

---

### Task 3: raider_reporter — screenshots first in the upload budget

**Files:**
- Modify: `lib/raider_reporter/writers/uploader.rb:54-73` (`within_budget`)
- Test: `spec/raider_reporter/writers/uploader_spec.rb` (next to "drops attachments beyond the byte budget…", line 48)

**Interfaces:**
- Consumes: `Payload#attachment_entries` (each `{attachment:, ...}`), `MAX_UPLOAD_ATTACHMENT_BYTES`, `MAX_UPLOAD_ATTACHMENTS`.
- Produces: same method signature. The selection becomes "all non-video entries in order, then video entries in order, until the byte or count limit". Survivors keep their original per-result order.

- [ ] **Step 1: Write the failing test**
```ruby
it "keeps screenshots ahead of an earlier video when the byte budget is exceeded" do
  # result A: clip.webm (40 MB); result B: shot.png (10 MB) — fixture files via File.truncate
  # stub MAX_UPLOAD_ATTACHMENT_BYTES at 45 MB (default)
  uploaded = parts_of(upload(payload))          # use the spec's existing multipart helpers
  expect(uploaded).to include("shot.png")
  expect(uploaded).not_to include("clip.webm")
  expect(warnings.join).to include("not uploading 1 attachment")
end
```
- [ ] **Step 2:** Run `bundle exec rspec spec/raider_reporter/writers/uploader_spec.rb`. Expected: the new test FAILS (the video is kept and the screenshot dropped).
- [ ] **Step 3:** Rewrite `within_budget` to build a set of entries to keep using that priority, then filter each result's attachments by membership in that set (replacing the `seen` counter). Keep the warning text exactly the same.
- [ ] **Step 4:** Run the uploader spec, then the full suite. Expected: PASS, including the existing budget and count-limit specs unchanged.
- [ ] **Step 5: Commit** `git commit -am "Upload screenshots before videos when over the attachment budget"`

---

### Task 4: raider_reporter — inline video player, release 0.10.0

**Files:**
- Modify: `lib/raider_reporter/writers/html.rb:220-234` (`attachments`) and the CSS block near `:265`
- Modify: `lib/raider_reporter/version.rb:4` → `"0.10.0"`, `CHANGELOG.md`, `README.md` ("Attaching screenshots and videos": document `max_video_bytes` and the upload ordering)
- Test: `spec/raider_reporter/writers/html_spec.rb` (next to "inlines images…", line 119)

**Interfaces:**
- Consumes: `safe_href(path)`.
- Produces: for `video/*`, `<video controls preload="metadata" src="HREF"></video><a href="HREF" download>NAME</a>`.

- [ ] **Step 1: Write the failing test**
```ruby
it "renders videos as an inline player with a download link and drops unsafe video paths" do
  html = render(attachments: [
    { "name" => "video", "content_type" => "video/webm", "path" => "attachments/a b/clip.webm" },
    { "name" => "evil", "content_type" => "video/mp4", "path" => "../x.mp4" }
  ])
  expect(html).to include(%(<video controls preload="metadata" src="attachments/a%20b/clip.webm"></video>))
  expect(html).to include(%(<a href="attachments/a%20b/clip.webm" download>video</a>))
  expect(html).not_to include("x.mp4")
end
```
- [ ] **Step 2:** Run `bundle exec rspec spec/raider_reporter/writers/html_spec.rb`. Expected: FAIL.
- [ ] **Step 3:** Add a `video/` branch in `attachments`. Add CSS: `.a video { max-width: 100%; max-height: 360px; display: block }`.
- [ ] **Step 4:** Run the full suite and `bundle exec rubocop`. Expected: PASS, no offenses. Then manually: `cd examples/rspec_basic`, attach any small `.webm` in the failing example, run `bundle exec rspec`, and open `raider-results/index.html`. The video plays.
- [ ] **Step 5: Commit and build**
```bash
git commit -am "Play video attachments inline in the HTML report; release 0.10.0"
gem build raider_reporter.gemspec   # publishing to rubygems is the user's call
```

---

### Task 5: ruby_raider — `RubyRaider::Ffmpeg` provisioning

**Files:**
- Create: `lib/ruby_raider/ffmpeg.rb` (must not require `thor` or anything under `lib/commands`)
- Create: `sig/ruby_raider/ffmpeg.rbs`
- Test: `spec/utilities/ffmpeg_spec.rb`

**Interfaces:**
- Produces (used by Tasks 6 and 7):
  - `RubyRaider::Ffmpeg::MANIFEST`: `{ version: String, assets: { 'darwin-arm64' => { url: String, sha256: String | nil }, ... } }` (placeholder `sha256: nil` for every platform until the release exists)
  - `RubyRaider::Ffmpeg.platform(host_os: RbConfig::CONFIG['host_os'], host_cpu: RbConfig::CONFIG['host_cpu']) -> String | nil`
  - `RubyRaider::Ffmpeg.cache_dir(env: ENV) -> String`
  - `RubyRaider::Ffmpeg.resolve(env: ENV, manifest: MANIFEST) -> String | nil` (no network: the env override if executable, else the cached binary)
  - `RubyRaider::Ffmpeg.ensure!(env: ENV, manifest: MANIFEST, fetch: method(:http_get), warn: ->(m) { $stderr.puts("[video] #{m}") }) -> String | nil`
  - `fetch` contract: `fetch.call(url, destination_path)` writes bytes and raises on failure.

- [ ] **Step 1: Write the failing tests** (use `Dir.mktmpdir` as `RAIDER_CACHE_DIR`, a test manifest whose `sha256` is the digest of `"#!/bin/sh\n"`, and a fake `fetch` that writes those bytes)
```ruby
describe RubyRaider::Ffmpeg do
  it 'maps host os/cpu to the four platforms and nil otherwise' do
    expect(described_class.platform(host_os: 'darwin23', host_cpu: 'arm64')).to eq('darwin-arm64')
    expect(described_class.platform(host_os: 'darwin23', host_cpu: 'x86_64')).to eq('darwin-x64')
    expect(described_class.platform(host_os: 'linux-gnu', host_cpu: 'x86_64')).to eq('linux-x64')
    expect(described_class.platform(host_os: 'mingw32', host_cpu: 'x64')).to eq('windows-x64')
    expect(described_class.platform(host_os: 'linux-gnu', host_cpu: 'aarch64')).to be_nil
  end
  it 'prefers RAIDER_FFMPEG_PATH and never downloads then'
  it 'ignores ffmpeg on PATH when no override is set'           # stub PATH to a dir containing ffmpeg; resolve → nil
  it 'downloads once, verifies, caches at <cache>/ffmpeg/<version>/ffmpeg, chmods +x'
  it 'makes no fetch call on a second ensure!'
  it 'deletes the file and returns nil with one warning on a checksum mismatch'
  it 'returns nil with "ffmpeg build not published yet" when the manifest sha256 is nil'
  it 'returns nil with one warning when fetch raises'
  it 'leaves exactly one valid binary when 4 threads call ensure! concurrently'   # Review Focus 3
end
```
- [ ] **Step 2:** Run `bundle exec rspec spec/utilities/ffmpeg_spec.rb`. Expected: FAIL (`uninitialized constant RubyRaider::Ffmpeg`).
- [ ] **Step 3:** Implement. Download to `<dest>.<pid>.<rand>.part`, verify with `Digest::SHA256.file`, then `File.rename` into place. Rename-wins handles concurrency: when the destination already exists and verifies, discard the `.part` file. `http_get` uses `Net::HTTP` with `use_ssl` required, follows up to 5 redirects to `https` only, and uses `open_timeout 10`, `read_timeout 60`.
- [ ] **Step 4:** Run the spec, then `bundle exec rspec spec/utilities`, `bundle exec rubocop lib/ruby_raider spec/utilities` and `bundle exec steep check` (the repo has a Steepfile). Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Add pinned, checksum-verified ffmpeg provisioning"`

---

### Task 6: ruby_raider — `raider u video install|status|on|off`

**Files:**
- Modify: `lib/commands/utility_commands.rb` (add after `desktop`, ~line 100; also fix the stray `desc 'config'` at line 71 by deleting it, since its options leak onto `timeout`)
- Modify: `lib/utilities/utilities.rb` (add `video_enabled=(Boolean)`, written to `config/config.yml` under `video.enabled`, following the existing setters)
- Test: `spec/commands/raider_commands_spec.rb` or a new `spec/utilities/video_command_spec.rb`, following `headless_config_spec.rb`

**Interfaces:**
- Consumes: `RubyRaider::Ffmpeg.ensure!`, `.resolve`, `MANIFEST[:version]`.
- Produces: CLI `raider u video SUBCOMMAND`.
  - `install`: exit 0 and print the path; exit 1 when `ensure!` returns nil.
  - `status`: print `ffmpeg <version>: <path>`, or `ffmpeg <version>: not installed`.
  - `on` / `off`: set `video.enabled`.

- [ ] **Step 1: Write the failing tests:** `install` exits 1 with the placeholder manifest; `off` then `on` round-trips `video.enabled` in a temp `config/config.yml`; `status` prints `not installed` with an empty cache; `timeout` no longer lists `config`'s options in `raider u help timeout`.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. `require 'ruby_raider/ffmpeg'` lazily inside the method, like `desktop` does.
- [ ] **Step 4:** Run the specs, then `bundle exec rspec spec/commands spec/utilities`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "Add raider u video install/status/on/off"`

---

### Task 7: ruby_raider — revive `VideoHelper` in generated projects

**Files:**
- Rewrite: `lib/generators/templates/helpers/video_helper.tt`. Drop `CdpRecorder` and `ScreenCaptureRecorder`, add `FrameRecorder`, keep `AppiumRecorder` and `NullRecorder`.
- Modify: `lib/generators/helper_generator.rb` (add `generate_video_helper` → `helpers/video_helper.rb`, for every project)
- Modify: `lib/generators/templates/common/partials/web_config.tt`, `mobile_config.tt` (append the `video:` block from Global Constraints)
- Modify: `lib/generators/templates/common/gemfile.tt:16` → `gem 'raider_reporter', '~> 0.10'`
- Test: `spec/integration/content/helper_content_spec.rb` (content) and `spec/generators/video_helper_spec.rb` (behaviour: render the template for selenium and appium into a tmp dir, `load` it, and drive it with test doubles)

**Interfaces:**
- Consumes: `RubyRaider::Ffmpeg.ensure!` (via `require 'ruby_raider/ffmpeg'`), `CAPTURE_MODE` from Task 1.
- Produces (used by Task 8):
  - `VideoHelper.enabled? -> Boolean`: `config['video']['enabled'] != false && ENV['VIDEO'] != 'off' && !@disabled`
  - `VideoHelper.recorder_for(driver_or_browser) -> recorder`: Appium driver → `AppiumRecorder`, Selenium or Watir → `FrameRecorder`, disabled or error → `NullRecorder`
  - `recorder.start -> nil` (no name argument; uses its own `Dir.mktmpdir`)
  - `recorder.stop(keep:) -> String | nil`. When `keep: false`, it discards frames without encoding and returns nil. When `keep: true`, it returns the path to `video.webm` (web) or `video.mp4` (Appium) inside the recorder's tmpdir, or nil.
  - `recorder.cleanup -> nil` (removes the tmpdir; Task 8 calls it after `attach`)
  - `VideoHelper.disable!(reason) -> nil`: warns `[video] <reason>; recording disabled for this run` once
  - If `CAPTURE_MODE == :listener`: `VideoHelper::FrameListener < Selenium::WebDriver::Support::AbstractEventListener` and `VideoHelper.listener -> FrameListener | nil`, which `driver_helper`/`browser_helper` pass as `listener:` when creating the driver.

- [ ] **Step 1: Write the failing tests**
```ruby
# content
it 'generates helpers/video_helper.rb with valid syntax for rspec_selenium, cucumber_watir, rspec_ios'
it 'config.yml has video: enabled: true, fps: 5, max_width: 1280'
it 'video_helper has no ScreenCaptureRecorder and no CdpRecorder'

# behaviour (fake driver double responds to save_screenshot(path) by writing a 1x1 PNG; fake ffmpeg is a shell script given via RAIDER_FFMPEG_PATH)
it 'stop(keep: false) never invokes ffmpeg and returns nil'
it 'stop(keep: true) invokes ffmpeg with libvpx and returns <tmpdir>/video.webm'
it 'returns nil and warns once when ffmpeg exits non-zero or writes 0 bytes'               # Review Focus 4
it 'returns nil, warns once, and does not raise when save_screenshot raises (driver quit)' # Review Focus 2
it 'two recorders started at once use different tmpdirs'                                    # Review Focus 1
it 'VIDEO=off makes recorder_for return a NullRecorder'
it 'scales frames to max_width via ffmpeg -vf scale=min(1280\,iw):-2'
```
- [ ] **Step 2:** Run `bundle exec rspec spec/integration/content/helper_content_spec.rb spec/generators/video_helper_spec.rb`. Expected: FAIL.
- [ ] **Step 3:** Implement the `CAPTURE_MODE` from Task 1. The capture interval is `1.0 / fps`. Encoder flags are the builder's choice (libvpx, `-deadline realtime`), as long as a 30 s failing test stays under 50 MB. Wrap every recorder method in `rescue StandardError => e; VideoHelper.disable!(e.message); nil`.
- [ ] **Step 4:** Run the specs, then `bundle exec rspec spec/integration/content` and `bundle exec rubocop`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "Generate VideoHelper with frame recorder and Appium recorder"`

---

### Task 8: ruby_raider — wire recording into RSpec and Cucumber hooks

**Files:**
- Modify: `lib/generators/templates/helpers/spec_helper.tt:3-61`
- Modify: `lib/generators/cucumber/templates/partials/selenium_env.tt`, `watir_env.tt`, `appium_env.tt`
- Test: `spec/integration/content/helper_content_spec.rb`, `spec/integration/content/cucumber_reporter_content_spec.rb`, `spec/integration/content/rspec_reporter_content_spec.rb`

**Interfaces:**
- Consumes: Task 7's `VideoHelper.recorder_for`, `start`, `stop(keep:)` and `cleanup`.
- Produces: `VideoHelper.final_attempt?(example) -> Boolean`, which lives in `video_helper.tt`. It's true when the example passed, or when `example.metadata[:retry_attempts].to_i + 1 >= (example.metadata[:retry] || RSpec.configuration.default_retry_count).to_i`. Confirm the metadata keys against the installed rspec-retry source before relying on them.

- [ ] **Step 1: Write the failing tests**
```ruby
it 'spec_helper requires video_helper, starts a recorder in before(:each) after the viewport resize'
it 'spec_helper attaches "video" only when example.exception && VideoHelper.final_attempt?(example)'
it 'spec_helper stops the recorder before quit_driver'
it 'cucumber envs (selenium, watir, appium) start in Before and attach "video" only when scenario.failed?, before quit'
it 'final_attempt? is false on attempt 1 of 3 and true on attempt 3 of 3 and when retry count is 0'  # in video_helper_spec.rb
```
- [ ] **Step 2:** Run the three content specs. Expected: FAIL.
- [ ] **Step 3:** Implement. The type is `type: :webm` for web and `type: :mp4` for Appium. Call `cleanup` in an `ensure`.
- [ ] **Step 4:** Run `bundle exec rspec spec/integration/content spec/generators`. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "Attach failure videos from RSpec and Cucumber hooks"`

---

### Task 9: ruby_raider — CI cache, docs, release 3.10.0, end-to-end acceptance

**Files:**
- Modify: `lib/generators/infrastructure/templates/github.tt` (before `Run tests`: an `actions/cache@v4` step for `~/.cache/raider`, keyed `raider-ffmpeg-<%= RubyRaider::Ffmpeg::MANIFEST[:version] %>-${{ runner.os }}`, then `bundle exec raider u video install`)
- Modify: `lib/generators/infrastructure/templates/github_appium.tt` (same, both jobs)
- Modify: `lib/generators/infrastructure/templates/azure_pipelines.tt` (`Cache@2` task with the same key and path, plus the install step)
- Modify: `lib/generators/templates/common/read_me.tt` (a "Video replay" section covering defaults, `VIDEO=off`, `raider u video ...` and the cache path), `README.md` ("What's Included" bullet plus an upgrade note for existing projects), `lib/version` → `3.10.0`
- Test: `spec/integration/content/ci_content_spec.rb`, `spec/integration/content/azure_content_spec.rb`, `spec/integration/content/readme_content_spec.rb`, `spec/integration/end_to_end_spec.rb`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the failing content tests:** the cache step and key appear in all three CI templates, before the tests step; `raider u video install` appears; the Readme mentions `VIDEO=off`.
- [ ] **Step 2:** Run them. Expected: FAIL. Then implement and re-run. Expected: PASS.
- [ ] **Step 3: End-to-end acceptance** (needs a temporary real manifest: point `RAIDER_FFMPEG_PATH` at a locally installed LGPL ffmpeg until the release exists). Add to `end_to_end_spec.rb`, tagged so it is skipped without a browser:
  - `rspec_selenium` with one forced failure (headless Chrome): `raider-results/attachments/**/video.webm` exists for the failing example only, and `index.html` contains `<video`
  - the same for `cucumber_watir` (Firefox)
  - `VIDEO=off`: no video files
  - a tampered cached binary: the suite's exit code equals the `VIDEO=off` exit code, and stderr has exactly one `[video]` line
  - manual (needs a simulator): `rspec_ios` against the sample app with one forced failure. `video.mp4` is attached and plays in the report and in desktop.
- [ ] **Step 4: Slowdown check:** the median of 5 runs of the generated sample suite, video on vs `VIDEO=off`, must be under 15%. Record the numbers in the PR description. **Over 15%: stop and ask the user.**
- [ ] **Step 5:** Run `bundle exec rspec` (full suite), `bundle exec rubocop` and `bundle exec reek`. Expected: PASS.
- [ ] **Step 6: Commit** `git commit -am "Cache ffmpeg in generated CI, document video replay; release 3.10.0"`

---

### Task 10: raider_desktop — scoped `raider-media://` protocol

**Files:**
- Create: `src/main/handlers/media/mediaProtocol.ts`
- Modify: `src/main/index.ts` (call `registerMediaScheme()` at module top level, before `app.whenReady` at line 120; call `registerMediaHandler()` inside `whenReady`)
- Test: `test/integration/mediaProtocol.test.ts`

**Interfaces:**
- Produces (used by Task 11):
  - `toMediaUrl(absPath: string): string` → `raider-media://file/${encodeURIComponent(absPath)}`. Export it from `src/renderer/src/foundation/mediaUrl.ts` (renderer side) and re-implement the decode in main.
  - `resolveMediaPath(requestUrl: string): Promise<string | null>`. Returns the absolute real path only if all of these hold: the host is `file`; the decoded path is absolute; `fs.promises.realpath(p) === path.normalize(p)` (rejects symlinks anywhere in the path); the final segments match `raider-results/attachments(-\d+)?/<name>` with no `..`; the extension is `.webm`, `.mp4` or `.mov`; `lstat` reports a regular file.
  - `parseRange(header: string | null, size: number): { start: number; end: number } | null`
  - `registerMediaScheme(): void` (`protocol.registerSchemesAsPrivileged([{ scheme: 'raider-media', privileges: { stream: true, supportFetchAPI: true } }])`), `registerMediaHandler(): void` (`protocol.handle('raider-media', ...)`). A 206 response is a `fs.createReadStream` slice with `Content-Range` and `Accept-Ranges: bytes`. A 200 response is the whole file. A path that fails the checks gets 404, and an unsatisfiable range gets 416.

- [ ] **Step 1: Write the failing tests** (tmp project dir with `raider-results/attachments/x/clip.webm`)
```ts
it('resolves a video under raider-results/attachments', ...)            // → real path
it('resolves under attachments-2 (shards)', ...)
it('rejects ../ escapes, relative paths, other hosts, .html/.png, missing files', ...) // → null
it('rejects a symlinked attachments dir and a symlinked file', ...)
it('rejects a file outside raider-results even if named attachments', ...)
it('parseRange: "bytes=0-" → {0,size-1}; "bytes=10-19" → {10,19}; "bytes=-5" → {size-5,size-1}; beyond size → null; garbage → null', ...)
```
- [ ] **Step 2:** Run `npx vitest run test/integration/mediaProtocol.test.ts`. Expected: FAIL.
- [ ] **Step 3:** Implement as specified above.
- [ ] **Step 4:** Run the test, then `npx vitest run` and `npm run lint` (or the repo's lint script). Expected: PASS.
- [ ] **Step 5: Commit** `git commit -m "Serve result videos through a scoped raider-media protocol"`

---

### Task 11: raider_desktop — video in results and result card, release 3.7.0

**Files:**
- Modify: `src/renderer/src/foundation/Types/testResult.ts` (add `video?: string`)
- Modify: `src/renderer/src/foundation/raiderResults.ts:68-71` (`toRow`: also pick the first `video/*` attachment through `safeAttachmentPath`, and set `row.video = \`${resultsDir}/${safe}\``)
- Create: `src/renderer/src/foundation/mediaUrl.ts` (`toMediaUrl`)
- Modify: `src/renderer/src/components/TestResultCard/index.tsx` (thread `video` through as `screenshot` is at lines 69 and 167; render it above the screenshot button near line 275)
- Modify: `package.json` version → `3.7.0`
- Test: `test/raiderResults.test.ts`, `test/components/TestResultCard.test.tsx`

**Interfaces:**
- Consumes: `toMediaUrl` (Task 10).
- Produces: `<video controls preload="metadata" src={toMediaUrl(video)} data-testid="result-video" />`, inside a collapsed `<details>` labelled with a new i18n key `testResult.video` in `src/renderer/src/assets/translations/en.json` (and every other locale file present).

- [ ] **Step 1: Write the failing tests**
```ts
it('maps the first video/* attachment to row.video under resultsDir', ...)
it('ignores a video with an unsafe path', ...)
it('renders a collapsed video player with a raider-media src when video is set', ...)
it('renders no video element when video is absent', ...)
```
- [ ] **Step 2:** Run `npx vitest run test/raiderResults.test.ts test/components/TestResultCard.test.tsx`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run `npx vitest run`. Then manually: `npm run dev`, open a project whose `raider-results` has a failing test with `video.webm`, and check that the card plays the video and seeking works (this exercises the range path).
- [ ] **Step 5: Commit** `git commit -am "Play failure videos in the result card; release 3.7.0"`

---

## Not in this plan (tracked elsewhere)

- Publishing the LGPL ffmpeg builds and filling in the real checksums. This is blocked on choosing who cuts the `ffmpeg-<version>` release. Once it's published, change only `MANIFEST` in `lib/ruby_raider/ffmpeg.rb` and re-run Task 9 Step 3 without `RAIDER_FFMPEG_PATH`.
- The RSpec retry attachment pile-up in raider_reporter (spec §3), as a separate ticket.
- Publishing the gems and the desktop release.
