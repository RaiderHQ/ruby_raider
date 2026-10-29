# Failed-Test Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In raider_desktop's project Dashboard and raider_saas, a failed test opens as one side-by-side card:
- the title
- the screenshot on the left
- the message and "Failed at file:line" on the right
- a stack trace that opens on demand, with project frames highlighted and other frames folded

On desktop, "Failed at" opens the file at that line.

**Architecture:**
- raider_reporter relativizes in-project backtrace frames, so a UI can recognise project frames without knowing the root.
- Each app gets a small pure frame helper (parse, classify, fold) and renders the card from it.
- SaaS stores `app_frame` per result, and its API presenter prefers that stored value.

**Tech Stack:** Ruby gem (RSpec), Electron + React + TypeScript (vitest, Playwright), Rails 8 + Hotwire + Tailwind (RSpec, SQLite and Postgres).

**Spec:** `docs/superpowers/specs/2026-10-28-failure-card-design.md` (in this repo). Read its "Decisions" and "Builder-check rulings" sections.

## Global Constraints

**Workspaces.** Create each worktree before its first task and work only there:

| Repo | Worktree | Branch | Base |
|---|---|---|---|
| raider_reporter | `~/raider_reporter-failure-card` | `feature/failure-card` | `feature/video-attachments` |
| raider_desktop | `~/raider_desktop-failure-card` | `feature/failure-card` | `feature/parity-cleanup` |
| raider_saas | `~/raider_saas-worktrees/failure-card` | `feature/failure-card` | `origin/main` (fetch first) |

- **Never touch** `~/raider_desktop`, `~/raider_saas` or `~/raider_reporter` working trees.
- **Desktop files that are off-limits:** recorder, codegen, `projectLayout.ts`, `rubyCommand.ts`, `appState`, suites, Overview tab bar/Tests tab, and `components/RecordingDashboard`. RecordingDashboard must render exactly as today.
- **SaaS files that are off-limits:** analytics files, `config/routes.rb`, `app/views/projects/show.html.erb` and `app/services/search/*`.
- **SaaS rules:**
  - Run `source dev-env.sh` before any Ruby command.
  - No inline `style=` or `on*=` attributes (CSP; enforced by `spec/requests/no_inline_handlers_spec.rb`).
  - RuboCop omakase.
  - SQL must work on SQLite and Postgres, with bound params.
  - Run the full suite on both adapters. For Postgres, touch only `raider_*` DBs: `DB_ADAPTER=postgresql RAILS_ENV=test bin/rails db:create db:schema:load && DB_ADAPTER=postgresql bundle exec rspec`.
  - Don't use ports 3000 or 3001.
  - Attachments only via `attachment_path`.
  - No Co-Authored-By or "Generated with" trailers.
- **Git:**
  - Commit on the task branch only.
  - Never stash, `checkout <sha>`, `reset --hard`, rebase or push.
  - Restore desktop `playwright-report/` and `test-results/` if a run modifies them.
- **`app_frame` length cap:** 500 characters (`AppFrame::MAX_LENGTH`, `ErrorGroup::SAMPLE_APP_FRAME_LIMIT`).
- **Display string:** "Failed at" shows `file:line` only. The full `app_frame` goes in the `title` attribute.
- **Screenshot slot:** the attachment named `screenshot`, else the first `image/*` attachment, else none (the right column takes the full width).
- **Browser:** shown only when the run's `environment["browser"]` is present.
- **Failing statuses:** desktop `failed` and `broken`; SaaS `TestResult::FAILING_STATUSES`. Other statuses render as today.

**Frame rules.** Both apps use these exact rules:
- `parseFrame(s)` matches `/\A((?:[A-Za-z]:)?[^:]+):(\d+)(?::in .*)?\z/` and returns `{ file, line }`, or null when there is no match.
- A frame is a **project** frame if either:
  - its file equals the parsed `app_frame` file, or
  - its file is relative (does not start with `/` or `X:`), does not start with `vendor/`, `.bundle/` or `<internal:`, and does not contain `/gems/`.
- Every other frame (including unparseable lines) is **other**.
- `foldFrames(lines, appFrame)` returns ordered segments. Each project line is `{ kind: 'project', text }`. Each maximal run of consecutive other lines is `{ kind: 'folded', lines }`, rendered as a toggle labelled "… N more" (N = lines.length) that expands to the dimmed lines.

## Review Focus

1. **Failure with an empty or missing backtrace and no `app_frame`** (RSpec `aggregate_failures`): the card shows the message only, with no "Failed at" and no trace toggle. Tested in Tasks 2, 4 and 6.
2. **`app_frame` points at a file that no longer exists in the project** (renamed test): "Failed at" is plain text, not a link, on desktop. Tested in Task 3.
3. **Windows-style frames** `C:/proj/spec/a_spec.rb:12:in 'x'`: the parser returns `{ file: 'C:/proj/spec/a_spec.rb', line: 12 }`, and the frame is "other" unless it equals the `app_frame` file. Tested in Tasks 2 and 6.
4. **SaaS result whose attachments expired (30 days)** or whose run has `results_purged_at`: the card renders without a screenshot slot and shows the existing expired note. No 500 error. Tested in Task 6.
5. **A long trace that is all "other"** (no project frames, e.g. a Selenium timeout raised in a gem): it folds into a single "… N more" toggle, and N matches the line count. Tested in Tasks 2 and 6.

---

### Task 1: reporter — project-relative backtraces

**Files:**
- Modify: `lib/raider_reporter/app_frame.rb`
- Modify: `lib/raider_reporter/rspec/formatter.rb` (`failure_for`)
- Modify: `lib/raider_reporter/cucumber/formatter.rb` (failure builder near the `backtrace:` line)
- Test: `spec/raider_reporter/app_frame_spec.rb`, plus the RSpec and Cucumber formatter specs under `spec/raider_reporter/`

**Interfaces:**
- Produces: `AppFrame.relativize(backtrace, root:) -> Array<String>`. Each line whose path resolves to a file inside `root` (using the same `inside_root` and symlink logic as `from`, and excluding `Gem.path`, rubylibdir, `vendor/` and `.bundle/`) is rewritten to `relative/path.rb:LINE…`, keeping the suffix. All other lines are returned unchanged. `nil` or empty input returns `[]`, and `root` nil returns the input unchanged.
- run.json and payload shape unchanged: `failure.backtrace` is still `Array<String>`, max 50.

- [ ] **Step 1: Write failing specs in `app_frame_spec.rb`.** Create real files in a tmp project root.
  - `"#{root}/spec/a_spec.rb:3:in 'x'"` becomes `"spec/a_spec.rb:3:in 'x'"`.
  - A gem path line is unchanged.
  - A `<internal:kernel>` line is unchanged.
  - A path through a symlinked root is relativized.
  - `relativize(nil, root:)` returns `[]`.
- [ ] **Step 2: Formatter specs.**
  - RSpec: the failing example's backtrace in run.json has the spec file as `spec/…_spec.rb:N` (relative).
  - Cucumber fixture under `spec/fixtures/cucumber`:
    - the backtrace contains the step definition as `features/step_definitions/…_steps.rb:N`
    - `app_frame` starts with `features/step_definitions/` (pins that Cucumber plumbing is skipped)
- [ ] **Step 3: Run** `bundle exec rspec spec/raider_reporter/app_frame_spec.rb` and the formatter specs. Expected: FAIL.
- [ ] **Step 4: Implement `relativize`.** Apply it in both formatters to the stored backtrace before `.first(MAX_BACKTRACE)`, with `root: RaiderReporter.project_root || Dir.pwd`, wrapped like `app_frame_for` (rescue to the unmodified backtrace). RSpec keeps `backtrace_formatter` first.
- [ ] **Step 5: Run** `bundle exec rspec`. Expected: all pass.
- [ ] **Step 6: Update the docs.** Add a CHANGELOG/README line: "Backtrace frames inside the project are written project-relative."
- [ ] **Step 7: Commit:** "Write in-project backtrace frames project-relative".

### Task 2: desktop — frame helpers and richer result rows

**Files:**
- Create: `src/renderer/src/foundation/stackFrames.ts`
- Modify: `src/renderer/src/foundation/raiderResults.ts`
- Modify: `src/renderer/src/foundation/Types/testResult.ts`
- Test: `test/stackFrames.test.ts`, `test/raiderResults.test.ts`

**Interfaces:**
- Produces in `stackFrames.ts`:
  - `parseFrame(s: string): { file: string; line: number } | null`
  - `isProjectFrame(line: string, appFrame?: string): boolean`
  - `type FrameSegment = { kind: 'project'; text: string } | { kind: 'folded'; lines: string[] }`
  - `foldFrames(lines: string[], appFrame?: string): FrameSegment[]`
  - All follow the Global Constraints rules.
- Produces in `testResult.ts`:
  - `export interface FailureInfo { message: string; exceptionClass?: string; backtrace: string[]; appFrame?: string }`
  - `TestResult` gains optional `failure?: FailureInfo`, `durationMs?: number` and `browser?: string`.
- `raiderResults.toRow` changes:
  - `statusDetails.message` is the sanitized message only. The backtrace is no longer appended.
  - It sets `failure` (with the backtrace and `app_frame` from run.json), `durationMs` from `duration_ms`, and `browser` from run.json `run.environment.browser`.
  - The screenshot is the attachment with `name === 'screenshot'`, else the first `image/*`.
  - `RaiderResult` gains `name?` on attachments, plus `duration_ms?` and `failure.exception_class?` / `failure.app_frame?`.

- [ ] **Step 1: Write failing `test/stackFrames.test.ts`.**
  - `parseFrame("spec/a_spec.rb:12:in 'x'")` returns `{file:'spec/a_spec.rb',line:12}`.
  - `parseFrame("C:/p/spec/a_spec.rb:12:in 'x'")` returns `{file:'C:/p/spec/a_spec.rb',line:12}`.
  - `parseFrame('garbage')` returns `null`.
  - `isProjectFrame` is true for `pages/login.rb:9`, false for `/usr/lib/ruby/gems/3.4.0/gems/x/y.rb:1`, false for `vendor/bundle/x.rb:1`, and false for `<internal:kernel>:1`.
  - `foldFrames([gemA, gemB, 'spec/a_spec.rb:12', gemC], 'spec/a_spec.rb:12:in x')` returns `[{folded,[gemA,gemB]},{project,'spec/a_spec.rb:12'},{folded,[gemC]}]`.
  - An all-gem input of 7 lines returns one folded segment of 7.
  - `foldFrames([], undefined)` returns `[]`.
- [ ] **Step 2: Extend `test/raiderResults.test.ts`.**
  - The message no longer contains the backtrace.
  - `failure.appFrame` and `failure.backtrace` are passed through.
  - `durationMs` is set.
  - `browser` comes from `run.environment.browser`, and is undefined when absent.
  - The screenshot prefers `name: 'screenshot'` over an earlier image.
  - A failure with no backtrace gives `failure.backtrace` `[]` and `appFrame` undefined.
- [ ] **Step 3: Run** `npx vitest run test/stackFrames.test.ts test/raiderResults.test.ts`. Expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `npx vitest run`, `npm run typecheck` and eslint on the changed files. Expected: green.
- [ ] **Step 6: Commit:** "Parse stack frames and carry failure details from run.json".

### Task 3: desktop — open a file at a line

**Files:**
- Create: `src/renderer/src/foundation/openInEditor.ts`
- Modify: `src/renderer/src/pages/FileEditor/index.tsx`
- Modify: `src/renderer/src/components/Editor/index.tsx`
- Test: `test/openInEditor.test.ts`, `test/FileEditor.test.tsx`

**Interfaces:**
- Produces:
  - `editorTargetFor(projectPath: string, appFrame: string): { fileName: string; filePath: string; line: number } | null`
    - Uses `parseFrame`.
    - Resolves a relative file against `projectPath`; an absolute file is used as is.
    - `fileName` is the basename.
    - Returns null if the frame is unparseable.
  - `async resolveEditorTarget(projectPath, appFrame, api: { readFile }) -> target | null`
    - Returns null when `api.readFile(filePath)` is not `success`.
- The `file-editor` location state becomes `{ fileName: string; filePath: string; line?: number }`.
- `Editor` gains an optional prop `revealLine?: number`. On mount, and when the prop changes, it calls `editor.revealLineInCenter(line)` and `editor.setPosition({ lineNumber: line, column: 1 })`, and adds a whole-line decoration, all via Monaco's `onMount`.
- Callers that pass no `line` behave as today.

- [ ] **Step 1: Write failing tests.**
  - `editorTargetFor('/p', "spec/a_spec.rb:12:in 'x'")` returns `{fileName:'a_spec.rb', filePath:'/p/spec/a_spec.rb', line:12}`.
  - An absolute frame is kept as is.
  - `'garbage'` returns `null`.
  - `resolveEditorTarget` returns `null` when the `readFile` mock returns `{success:false}`.
  - `FileEditor` with state `{fileName, filePath, line: 7}` renders `Editor` with `revealLine={7}` (mock `@components/Editor`).
  - `FileEditor` without a `line` passes `revealLine` as undefined.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the full vitest suite and typecheck. Expected: green.
- [ ] **Step 5: Commit:** "Open the file editor at a given line".

### Task 4: desktop — the failure card (layout B) on the project Dashboard

**Files:**
- Create: `src/renderer/src/components/FailureDetails/index.tsx`
- Modify: `src/renderer/src/components/TestResultCard/index.tsx`
- Modify: `src/renderer/src/components/ProjectDashboard/index.tsx`
- Modify: `src/renderer/src/assets/locales/en.json` (or wherever en.json lives)
- Test: `test/components/FailureDetails.test.tsx`, `test/ProjectDashboard.test.tsx`

**Interfaces:**
- Consumes:
  - from Task 2: `FailureInfo`, `foldFrames`, `parseFrame`, and `TestResult.failure/durationMs/browser`
  - from Task 3: `resolveEditorTarget`, and the `file-editor` state with `line`
- `FailureDetails` props: `{ failure: FailureInfo; screenshot?: string; durationMs?: number; browser?: string; projectPath?: string; onOpenScreenshot?: () => void }`.
- `TestResultCard` gains optional props `failure?: FailureInfo`, `durationMs?: number`, `browser?: string` and `projectPath?: string`.
  - When `failure` is set and the status is failed or broken, the expanded body renders `FailureDetails` in place of the message, screenshot and backtrace block.
  - The existing "Failure video" section stays below it, unchanged (`data-testid="result-video"` and its summary text are kept).
  - The existing a11y message parsing still applies to `failure.message`.
- Only `ProjectDashboard` passes `failure`. RecordingDashboard is untouched.

**Layout:**
- Left column: the screenshot thumbnail (reuse the card's existing modal-open behaviour), about 45% width, shown only when a screenshot exists.
- Right column, top to bottom:
  - exception class (small, red)
  - message
  - `Failed at <button>file:line</button>` with `title={appFrame}`, plus `· {durationMs} ms` and `· {browser}` when present. The button is a plain `<span>` when `resolveEditorTarget` returns null.
  - a "Stack trace" toggle, closed by default. It renders segments as follows:
    - project lines: highlighted (`bg-yellow-100 font-semibold`)
    - folded runs: a "… N more" button that expands to the lines in `text-neutral-mid`
- Test IDs:
  - `failure-details`
  - `failure-location`
  - `stack-trace-toggle`
  - `stack-frame-project`
  - `stack-frames-folded`

- [ ] **Step 1: Write failing `FailureDetails` tests.**
  - It renders the message and exception class.
  - The `failure-location` text is `spec/a_spec.rb:12` and its title is the full `app_frame`.
  - Clicking it (with the `readFile` mock returning success) calls `navigate('/file-editor', {state:{fileName:'a_spec.rb', filePath:'/p/spec/a_spec.rb', line:12}})`.
  - With `readFile` failing, it is not a button.
  - Without `appFrame` and with an empty backtrace, there is no `failure-location` and no `stack-trace-toggle`.
  - The trace is closed initially. After the toggle, there is 1 `stack-frame-project`, and a `stack-frames-folded` reading "… 2 more".
  - Without a screenshot, no `img` is rendered.
- [ ] **Step 2: Extend `ProjectDashboard.test.tsx`.** A failed raider result renders `failure-details`, and a passed one does not.
- [ ] **Step 3: Run them.** Expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** vitest, typecheck and eslint. Then run `npx electron-vite build && npx playwright test e2e/failure-video.spec.ts e2e/dashboard-page.spec.ts`. Expected: green. The failure-video spec's selectors must still pass.
- [ ] **Step 6: Commit:** "Show failures as a side-by-side card with a foldable stack trace".

### Task 5: SaaS — store `app_frame` per result

**Files:**
- Create: `db/migrate/<timestamp>_add_app_frame_to_test_results.rb`, which adds `t.string :app_frame, limit: 500`, nullable
- Modify: `db/schema.rb` (regenerated), `app/services/ingest.rb` (`insert_results`), `app/presenters/api/v1/build_presenter.rb` (`failure`)
- Test: the ingest spec under `spec/services`, `spec/requests/api` build specs, and `spec/requests/mcp_tools_spec.rb` if it asserts `app_frame`

**Interfaces:**
- `test_results.app_frame`: string or nil. It is written at ingest from `failure["app_frame"]` for failing statuses only, truncated with `.to_s.first(ErrorGroup::SAMPLE_APP_FRAME_LIMIT).presence`.
- `BuildPresenter#failure` sets `app_frame: result.app_frame.presence || Failures::Signature.fallback_frame(result.backtrace)`. The OpenAPI shape is unchanged.

- [ ] **Step 1: Write failing specs.**
  - Ingesting a failed result with `app_frame: "spec/a_spec.rb:12:in 'x'"` stores it.
  - A 600-character `app_frame` is stored truncated to 500.
  - A passed result stores nil.
  - The API build detail returns the stored `app_frame` when present, and the `fallback_frame` value when the column is nil. The response is still valid against `docs/openapi.yaml`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.** Add the migration, run `bin/rails db:migrate`, then add the ingest and presenter changes.
- [ ] **Step 4: Run** the full suite on SQLite and on Postgres, plus `bin/rubocop`. Expected: green.
- [ ] **Step 5: Commit:** "Store app_frame per test result and prefer it in the API".

### Task 6: SaaS — the failure card (layout B)

**Files:**
- Create: `app/helpers/stack_trace_helper.rb`
- Modify: `app/views/test_results/_card.html.erb`, splitting into a partial `app/views/test_results/_failure.html.erb` if that is clearer
- Test: `spec/helpers/stack_trace_helper_spec.rb`, `spec/requests/run_detail_spec.rb`

**Interfaces:**
- Consumes: from Task 5, `TestResult#app_frame`.
- Produces in `StackTraceHelper`:
  - `parse_frame(str) -> { file:, line: } | nil`
  - `project_frame?(line, app_frame) -> Boolean`
  - `fold_frames(lines, app_frame) -> Array<Hash>`, where each segment is `{ kind: :project, text: }` or `{ kind: :folded, lines: [] }`
  - `failure_location(app_frame) -> "file:line" | nil`
  - All follow the Global Constraints rules. Backtrace lines come from `result.backtrace.to_s.split("\n")`.

**Card changes:**
- Keep the `<details>` summary row unchanged.
- For failing results, the open body becomes layout B:
  - **Left:** the screenshot `<img>` (named `screenshot`, else the first image), still via `attachment_path` and `lightbox#open`, rendered only when attachments exist and haven't expired.
  - **Right:**
    - the exception class and message box, as today
    - `<p data-testid="failure-location" title="<full app_frame>">Failed at <code>file:line</code> · browser</p>`, with the browser from `result.run.environment["browser"]` when present
    - `<details data-testid="stack-trace">`, with the summary "Stack trace". Project lines go in `<span data-testid="stack-frame-project">` with a highlight class. Each folded run is a nested `<details data-testid="stack-frames-folded"><summary>… N more</summary>…dimmed lines…</details>`.
  - **Below both columns:**
    - `<details>` "Failure video" around any video attachment
    - other attachments listed as today
    - the existing expired and purged notes
- Non-failing results render as today.
- No JavaScript and no inline styles.

- [ ] **Step 1: Write a failing helper spec.**
  - The same cases as Task 2 Step 1, in Ruby.
  - `failure_location("spec/a_spec.rb:12:in 'x'")` returns `"spec/a_spec.rb:12"`.
  - `failure_location(nil)` returns `nil`.
- [ ] **Step 2: Write failing request specs in `run_detail_spec.rb`.**
  - A failing result with an `app_frame` and a screenshot attachment renders `[data-testid=failure-location]` with the text `spec/a_spec.rb:12` and the screenshot `img`.
  - A failing result without attachments renders no `img` and still shows the message.
  - A failing result whose attachments are expired shows `attachments-expired` and no `img`.
  - A failing result with no `app_frame` and no backtrace has no `failure-location` and no `stack-trace`.
  - An all-gem backtrace of 7 lines renders one `stack-frames-folded` with "… 7 more".
  - A run with `environment: {"browser" => "chrome"}` shows "chrome".
  - A passed result renders no `failure-location`.
- [ ] **Step 3: Run them.** Expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** the full suite on SQLite and Postgres (including `no_inline_handlers_spec`), plus `bin/rubocop`. Expected: green. Also render one run page with a failing result in a local server on port 3002 and screenshot it for the review.
- [ ] **Step 6: Commit:** "Show failures as a side-by-side card with a foldable stack trace".
