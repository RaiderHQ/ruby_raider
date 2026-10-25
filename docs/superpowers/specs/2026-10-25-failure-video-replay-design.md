# Failure video replay

Date: 2026-10-25
Status: approved 2026-10-25

Open items (approved as drafted; confirm before the step they block):
- RaiderHQ re-hosts LGPL ffmpeg builds, as drafted. **Still unassigned:** who cuts the `ffmpeg-<version>` release. That person blocks the real checksums in the manifest, so build against a placeholder manifest until then.
- The 15% slowdown limit stands as drafted. If the spike misses it, **stop and ask** which gives way (the limit, the frame rate, or default-on for some browsers) rather than choosing.
Repos touched: ruby_raider (3.9.0 → next minor), raider_reporter (0.9.0 → next minor), raider_desktop (3.6.0 → next minor)

## Intent

When a test fails, the developer opens the report on their own machine and presses play to watch what the browser or app did. That is the first Playwright parity gap we are closing (see the parity audit: video and trace were the top gap once Playwright-as-automation and a Raider DSL were ruled out).

Failures are usually investigated **locally**, so the local experience comes first. CI must work too, but is secondary.

## Goals

1. Newly generated web and mobile projects record a video of every test **by default** and keep it **only when the test fails** (Playwright's `retain-on-failure`).
2. Nothing has to be installed by hand. Like Playwright, Raider fetches its own ffmpeg on first use.
3. The video plays inline in the raider_reporter HTML report and in the raider_desktop result card.
4. The video is a normal file (WebM) that can be downloaded and shared.
5. If recording is impossible (download failed, unsupported platform, recorder error), tests still run and pass or fail on their own merits. One warning, no video.

## Non-goals

- Step-by-step trace (actions + screenshots + console). Later feature; the user chose video replay first.
- Playwright as an automation choice, or a Raider-owned locator/wait DSL (standing product decisions).
- Raider server changes. Videos upload under the existing 45 MB / 1000-file budget; anything past it stays local, as today.
- Videos for passing tests, or a "record everything" mode in v1.
- Upgrading existing generated projects automatically. Only new projects get this; an upgrade note in the README is enough.

## Anti-goals (would make this a failure even if it works)

- A test that would pass fails, hangs, or becomes flaky because recording is on.
- Raider downloads and runs a binary it did not verify.
- The default suite gets noticeably slower. Target: under 15% added wall time on the generated sample suite. *(My number; adjust if you want a different budget.)*
- Report folders balloon because passing-test videos were kept.

## Decisions made

| Decision | Made by |
|---|---|
| Video replay before trace | user |
| Local machine is the primary place failures are investigated | user |
| ffmpeg is downloaded automatically (option 1), not a zero-binary frame player | user |
| Video is on by default in new projects | user |
| Binaries are re-hosted by RaiderHQ as GitHub release assets, pinned, SHA-256 verified | Claude's call |
| LGPL ffmpeg build, WebM/VP8 output (avoids GPL H.264 obligations; Playwright made the same choice) | Claude's call |
| Web recording = periodic page screenshots (works for any Selenium/Watir browser, headless or headed, never captures the rest of the desktop); mobile = Appium's native `start_recording_screen` | Claude's call |
| Screen-capture recorder (`ScreenCaptureRecorder`, full desktop via avfoundation/x11grab/gdigrab) is dropped | Claude's call |
| Downloader lives in the ruby_raider gem, which every generated project already has in its Gemfile | Claude's call |

## Design

### 1. ffmpeg provisioning (ruby_raider)

New module `RubyRaider::Ffmpeg` in `lib/utilities/ffmpeg.rb`, requirable from generated projects (`require 'utilities/ffmpeg'` or a small `ruby_raider/ffmpeg` entry point; builder's choice, but it must not load Thor).

- **Pinned manifest** in the gem: ffmpeg version, and per platform (`darwin-arm64`, `darwin-x64`, `linux-x64`, `windows-x64`) the asset URL on a RaiderHQ GitHub release and its SHA-256.
- **Cache path:** `~/.cache/raider/ffmpeg/<version>/ffmpeg[.exe]` (`%LOCALAPPDATA%\raider\ffmpeg\…` on Windows). Override with `RAIDER_FFMPEG_PATH` (use this binary, no download) and `RAIDER_CACHE_DIR`.
- **Resolution order:** `RAIDER_FFMPEG_PATH` → cached pinned binary → download. A system `ffmpeg` on PATH is **not** used by default (unknown build/licence/codecs); allowed only via `RAIDER_FFMPEG_PATH`.
- **Download:** HTTPS only, follow GitHub redirects, timeouts like `DesktopDownloader` (10s open / 15s read, longer total for the ~20–40 MB file), write to a temp file, verify SHA-256, then atomic rename and `chmod +x`. Checksum mismatch → delete, warn, no video. Concurrent processes (parallel_tests) must not corrupt the cache: lock file or rename-wins.
- **Offline / CI:** `raider u video install` downloads and verifies ahead of time; `raider u video off|on` toggles `config.yml`; `raider u video status` prints the resolved binary and version.
- Unlike `DesktopDownloader`, never query "latest". The manifest is the source of truth, bumped deliberately in a gem release.

**Release chore (RaiderHQ):** publish the LGPL ffmpeg builds as assets on a dedicated release (e.g. `RaiderHQ/ruby_raider` tag `ffmpeg-<version>`), keep the LICENSE/source-offer text next to them, and record checksums in the manifest. Source of the upstream builds is the builder's call, but it must be an LGPL configuration with `libvpx` enabled for every platform listed.

### 2. Recording in generated projects (ruby_raider templates)

Revive `lib/generators/templates/helpers/video_helper.tt` (orphaned since 366946e) and generate it as `helpers/video_helper.rb` for every project.

- **Config** (`common/partials/web_config.tt`, `mobile_config.tt`):
  ```yaml
  video:
    enabled: true
    fps: 5
    max_width: 1280
  ```
  `HEADLESS`-style env override: `VIDEO=off` disables for one run.
- **Web recorder** (`FrameRecorder`, replaces `CdpRecorder`): captures page screenshots on an interval into a per-test temp dir, then encodes with the provisioned ffmpeg to `video.webm` (VP8). Works for Chrome, Firefox and Edge via Selenium, and for Watir (which wraps the Selenium driver).
- **Mobile recorder:** keep `AppiumRecorder`. Write the result as-is (mp4 from Appium; no re-encode needed; reporter already knows `video/mp4`).
- **Hooks:**
  - RSpec `spec_helper.tt`: start in `before(:each)` after driver setup; in `after(:each)`, stop. If `example.exception`, encode and `RaiderReporter.attach('video', path, type: :webm)` next to the existing screenshot; otherwise discard frames without encoding.
  - Cucumber `*_env.tt`: same in `Before` / `After`, keyed on `scenario.failed?`.
  - Encoding happens **only for failures**, so passing tests pay capture cost but not encode cost.
- **Retries** *(Claude's call)*: each attempt records its own video. The template attaches a video only on the final attempt, for example when the attempt number equals the retry count or the example is no longer going to be retried. Earlier attempts' frames are thrown away without being encoded. This is enforced in the template, not left to raider_reporter. Cucumber already keeps only the final attempt.
- **Failure isolation:** every recorder call is wrapped; any error → warn once per run, disable recording for the rest of the process, never raise into the test.

**Known risk the builder must spike first:** the current `CdpRecorder` calls `save_screenshot` from a background thread while the test thread drives the same Selenium session. Selenium's Ruby client is not documented as thread-safe for concurrent commands on one bridge. The spike must show whether this is safe across Chrome and Firefox under the sample suite. If it is not, acceptable fallbacks in order: (a) capture after each driver command via Selenium's built-in event listener (`listener:` on driver creation; Watir passes it through) plus a final frame; (b) a second HTTP client bound to the same session id. Pick whichever passes the anti-goals. Record the result in this doc.

### 3. Reporter (raider_reporter)

- **Size cap:** add `max_video_bytes` (default 50 MB) applied when the resolved content type is `video/*`; `max_attachment_bytes` (5 MB) keeps applying to everything else. Over the cap → existing warning, not attached.
- **`type: :webm`** already maps to `video/webm` (`content_types.rb`). No schema change: videos are ordinary attachments.
- **HTML report** (`writers/html.rb` `attachments`): for `video/*`, render `<video controls preload="metadata" src="…">` with a download link beneath, through the existing `safe_href` checks. Keep images as they are.
- **Upload ordering** *(Claude's call)*: today `Uploader#within_budget` keeps attachments in order until 45 MB, so one early video could push every later screenshot out of the upload. Change the order so all non-video attachments go first, then videos fill whatever room is left. Videos that don't fit stay local, with the existing warning.
- **Server:** no change needed. raider_saas already serves `video/mp4` and `video/webm` inline (`app/controllers/attachments_controller.rb:11`) and renders `<video controls>` for them (`app/views/test_results/_card.html.erb:37-38`).
- **RSpec retry pile-up (separate bug, noted, not fixed here):** the RSpec formatter calls `start_test` once per example, while rspec-retry reruns `after(:each)` on every attempt, so attachments from every failed attempt may pile up. The builder should confirm this with a test. This design avoids it for video by attaching only on the final attempt (see Hooks). The screenshot behaviour is a separate ticket.

### 4. Desktop (raider_desktop)

- `foundation/raiderResults.ts`: alongside the first image, pick the first `video/*` attachment, through the same relative-path guard (`attachments(-N)?/…`).
- `TestResultCard`: when a video is present, show an inline player (HTML5 `<video>`; Electron's Chromium plays WebM and MP4) above the screenshot, collapsed by default for long lists.
- **Serving the file** *(Claude's call)*: screenshots go through the `readImage` IPC as base64 data URLs, which is unworkable for videos up to 50 MB. Register a custom Electron protocol (e.g. `raider-media://`) whose handler serves only files under `<project>/raider-results/attachments(-N)?/`. It resolves real paths, rejects symlinks and `..` (same rules as the existing open-report handler), and supports range requests so the player can seek. Do not enable general `file://` access.

### 5. CI templates (ruby_raider)

- `github.tt`, `github_appium.tt`, `azure_pipelines.tt`: cache `~/.cache/raider` between runs (actions/cache, Azure `Cache@2`) keyed on the gem's ffmpeg version, and add a `raider u video install` step before tests so a download failure is visible as its own step.
- `raider-results/` artifact upload already includes `attachments/`, so videos ride along.

## Acceptance

- `raider new demo -p framework:rspec automation:selenium`, then `bundle exec rspec` with one deliberately failing example, on a clean macOS machine with no ffmpeg installed: ffmpeg downloads once, the failing example has `video.webm` in `raider-results/attachments/`, passing examples have none, and `raider-results/index.html` plays it inline.
- Same for Cucumber, Watir, Firefox, and headless Chrome.
- Second run makes no network request for ffmpeg.
- Tampered cached binary (checksum mismatch) or no network: tests run, one `[video]` warning, no video, exit code unchanged.
- Appium iOS sample with a failing test: mp4 attached and playable in report and desktop.
- raider_desktop result card for the failing test plays the video.
- Generated sample suite wall time with video on is within the slowdown budget vs `VIDEO=off`.
- Generated GitHub Actions workflow passes with the cache step; second run hits the cache.

## Left to the builder

- Exact require path / module layout for `RubyRaider::Ffmpeg`.
- Upstream source of the LGPL ffmpeg builds, and the release tag name.
- Frame naming, temp-dir layout, encoder flags (VP8 bitrate/quality), as long as a 30 s failing test produces a video under the 50 MB cap.
- Desktop player styling.
- Spec layout for content/integration tests (follow the existing `spec/integration/content/*_content_spec.rb` pattern).
