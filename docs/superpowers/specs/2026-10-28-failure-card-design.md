# Failed-test card: design

Parity item #2 (Raider ↔ Playwright). Date: 2026-10-28.

## Intent

When a test goes red, the user wants to see what broke without digging through
terminal output or re-running. Opening a failed test should answer "what broke and
where" on one card: title, screenshot, a quick description and a stack trace they
can open. This is Playwright's error view, adapted to Raider. The user named the
order (title, screenshot, quick description, openable stack trace), chose layout
B (side by side), and wants it in **raider_desktop and raider_saas**.

## Goals

1. One failed-test card layout, shared in spirit by desktop and SaaS:
   - **Header:** FAILED badge and the test's full name.
   - **Left:** the failure screenshot (the first image attachment). If there is
     none, the right column takes the full width.
   - **Right, quick description:**
     - the error message, with the exception class above it as today in SaaS
     - "Failed at `<app_frame>`", the first line of the trace in the user's own
       project, e.g. `spec/login_spec.rb:12`
     - duration
     - browser, when known
   - **Stack trace:** collapsed by default. When opened, project frames are
     highlighted and gem/framework frames dimmed. Runs of consecutive dimmed
     frames fold into "… N more", which can be clicked to expand.
   - **Failure video:** a collapsed section under the trace, as today.
2. **Desktop:** clicking "Failed at …" opens that file at that line in the app's
   editor.
3. **Cucumber traces get the same project-frame treatment as RSpec.** Today
   RSpec traces are pre-filtered by RSpec's backtrace formatter, but Cucumber
   traces keep every gem line, so the user's line is buried.

## Non-goals

- Test stdout/stderr capture and per-attempt retry details. These were in the
  original #2 scope; the user's answers pointed at the stack trace and visuals,
  and they didn't ask for them back. Possible later item.
- Inline source-code snippets around the failing line (Playwright shows these).
  Not asked for; "Failed at" plus open-in-editor covers it on desktop.
- The raider_reporter HTML report. It already has a collapsible backtrace, so it
  is left as is (my call).
- Steps, timeline, trace viewer.

## Anti-goals

- The card must not hide the full trace. Dimming and folding are presentation
  only; every frame is still reachable.
- No guessing at the project line in the UI when the reporter didn't record one.
  In that case, omit "Failed at" rather than show a wrong line.
- Don't break existing callers of the desktop editor route.

## What exists today (verified in code)

- **raider_reporter:**
  - `failure` in run.json and the upload payload has `message`,
    `exception_class`, `backtrace` (max 50 lines) and optional `app_frame`
    (`lib/raider_reporter/app_frame.rb`: the first frame inside the project root,
    excluding vendor/bundle/gem paths; at most 500 characters).
  - RSpec backtraces are filtered by `RSpec.configuration.backtrace_formatter`.
    Cucumber backtraces are raw, the first 50 lines.
  - Results also carry `duration_ms` and `attempts`.
  - There is no browser field. `run.environment` is a user-configurable hash
    (`RaiderReporter.configure { |c| c.environment = {...} }`).
- **raider_desktop:**
  - `foundation/raiderResults.ts` `toRow` joins message + backtrace into one
    `statusDetails.message` string and ignores `app_frame`.
  - `TestResultCard` renders a message and an optional backtrace.
  - `ProjectDashboard` uses `loadRaiderResults`.
  - Editor route is `file-editor` (`Router.tsx:23`). It reads
    `location.state as { fileName, filePath }`, with no line.
- **raider_saas:**
  - `app/views/test_results/_card.html.erb` is a `<details>` card: the summary
    holds status, name, pills, attempts, duration and a History link. The body
    holds the exception box, a collapsible raw backtrace `<pre>`, an attachments
    row (images go to the lightbox, videos are inline) and an expired-attachments
    note.
  - `test_results` has no `app_frame` column. `app_frame` is only kept as
    `error_groups.sample_app_frame`.
  - `Api::V1::BuildPresenter` derives `app_frame` with
    `Failures::Signature.fallback_frame(backtrace)`.

## Decisions

- **Layout B (side by side)** in both apps. User decision.
- **The project line comes from the reporter's `app_frame`.** The reporter is
  the only place that knows the project root, so the UI never re-derives it.
  Exception: SaaS's existing `fallback_frame` stays as the API fallback for old
  rows.
- **Classifying frames as project vs. dimmed (for highlighting).**
  - A frame is "project" if its path matches the `app_frame` file, or if it is a
    relative path not under `vendor/`, `.bundle/`, `gems/` or `<internal:`.
    Everything else is dimmed.
  - This is a small pure function per app (TS on desktop, Ruby helper on SaaS)
    with unit tests over RSpec-style and Cucumber-style traces.
  - My call: classify in the UI so old run.json files and old SaaS rows also
    benefit, rather than adding a per-frame flag to the payload.
- **Cucumber filtering in the reporter.**
  - Keep the raw trace, so nothing is lost and the anti-goal holds.
  - Fix `app_frame` for Cucumber so it skips Cucumber's own step-definition
    plumbing and lands on the user's step definition or page object.
  - Verify this with a Cucumber fixture. If it already does, this becomes a test
    only.
- **Browser.** See the builder-check rulings below.
- **Desktop open-at-line.**
  - Add an optional `line?: number` to the `file-editor` location state. The
    editor scrolls to and highlights that line when it is present. Existing
    callers are unchanged.
  - "Failed at" resolves `app_frame`'s relative path against the project path.
    It is clickable only if the file exists; otherwise it is plain text.
  - Per the desktop session: keep `app_frame` parsing and the open-at-line helper
    generic (in `foundation/`, not inside the Dashboard component), because their
    later plans merge dashboards and add `/tests/:id`.
- **SaaS storage.**
  - Add a nullable `test_results.app_frame` column, written at ingest from
    `failure.app_frame` and capped like `SAMPLE_APP_FRAME_LIMIT`.
  - `BuildPresenter` prefers the stored value and falls back to
    `fallback_frame`, so the API, MCP and the card agree. The OpenAPI shape is
    unchanged (a nullable string).
- **SaaS card layout.**
  - Keep the `<details>` summary row as is.
  - Restructure the open body to layout B: screenshot left (still the lightbox),
    right column with exception class, message, "Failed at …" and the
    collapsible trace with highlighted, dimmed and folded frames.
  - Videos go in a collapsed "Failure video" section. Other attachments stay
    listed below.
  - Handle the cases where attachments are expired or purged (show the existing
    note; the right column takes the full width) and where the run has
    `results_purged_at`.
- **Passing and other non-failing results** keep today's rendering in both apps.
  Only failing statuses (`TestResult::FAILING_STATUSES` in SaaS, failed and
  broken on desktop) get the new body.

### Builder-check rulings (my calls, 2026-10-28)

- **Absolute paths in traces.**
  - The reporter rewrites backtrace frames that lie inside the project root to
    root-relative paths before writing run.json and the payload. It reuses
    `AppFrame`'s root and symlink logic. Frames outside the root stay as they
    are.
  - The UI rule "relative path not under vendor/.bundle/gems/<internal:" then
    holds for both RSpec and Cucumber.
  - Older data with absolute paths degrades gracefully: only the `app_frame`
    file is highlighted. This supersedes the "no per-frame flag" concern
    because nothing new is added to the schema.
- **"Failed at" display.**
  - Show `file:line` only, dropping the `:in '…'` suffix.
  - The full `app_frame` string is the element's title/tooltip.
  - One parse helper per app, `parseFrame(str) -> { file, line } | null`, tested
    against RSpec frames, Cucumber frames, `:in` suffixes and Windows drive
    paths.
- **Screenshot slot.**
  - Use the attachment named `screenshot`. ruby_raider's `spec_helper.tt`
    attaches it as `RaiderReporter.attach('screenshot', …)`.
  - Fall back to the first `image/*` attachment.
  - Other images stay in the attachments list.
- **RecordingDashboard.** Out of scope; it is recorder-adjacent and the desktop
  session will merge dashboards later. The new failure body is opt-in on
  `TestResultCard` (for example a prop, or a separate `FailureDetails`
  component) and enabled only from `ProjectDashboard`. RecordingDashboard
  renders exactly as today.
- **Browser.**
  - Dropped from the ruby_raider deliverables. Generated projects never call
    `RaiderReporter.configure`, and adding it would mean new generator surface.
  - The cards show the browser only when `run.environment["browser"]` is
    present, which users can set themselves. Otherwise the card shows duration
    only.
- **Base and order.**
  - Desktop builds on `feature/parity-cleanup` (PR #74) in a new worktree,
    stacked as a new PR.
  - The desktop session said it will rebase its later dashboard and `/tests/:id`
    plans on top of this work, so this lands first.
  - Helpers live in `src/renderer/src/foundation/` as planned.

## Constraints

- **Ownership (other sessions).**
  - Desktop: the recorder, codegen, `projectLayout.ts`, `rubyCommand.ts`,
    `appState`, suites, the Overview tab bar and the Tests tab belong to the
    desktop session. These files are clear: `raiderResults.ts`,
    `TestResultCard`, `ProjectDashboard`, `FileEditor`, `Router.tsx` and
    `components/Editor`.
  - Desktop work goes in its own worktree, on top of `feature/parity-cleanup`
    (PR #74).
  - SaaS: work in a new worktree off `origin/main` (never `~/raider_saas`). The
    SaaS session's analytics files, `config/routes.rb` and the projects/show
    Analytics link are off-limits.
- **SaaS rules.**
  - Run `source dev-env.sh` first (Ruby 4.0.2).
  - CSP is enforced: no inline `style=` or `on*=`. JS goes in Stimulus via
    importmap.
  - RuboCop omakase.
  - SQL must work on both SQLite and Postgres, with bound params.
  - Run the full suite on both adapters (Postgres: only `raider_*` databases).
  - Don't use ports 3000 or 3001.
  - Attachments go through `attachment_path` (presigned 302), never blob URLs.
  - Commits carry no Co-Authored-By or generated trailers.
- **General.** No pushes or PRs without the user's okay.

## Left to the builder

- Exact Tailwind classes and spacing, matching each app's existing card style.
- How the editor scrolls and highlights a line (CodeMirror or Monaco, whichever
  `components/Editor` uses).
- Which fixtures and tests are needed beyond the classification unit tests, the
  open-at-line test, the ingest/presenter specs and one request spec per card
  state (failing with screenshot, without screenshot, attachments expired, no
  app_frame).
