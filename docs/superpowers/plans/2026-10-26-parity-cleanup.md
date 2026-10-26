# Parity Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ruby_raider, raider_reporter and raider_desktop agree on what Raider supports. Remove Capybara, Minitest and Adopt. Fix desktop commands the gem rejects. Align versions. Correct the docs.

**Architecture:** This is a cleanup only, with no new features. The gem is the source of truth for what Raider generates and accepts. Desktop and docs move to match it. The one behaviour change in the gem is that `raider` exits non-zero on errors.

**Tech Stack:** Ruby/Thor/RSpec (gem, reporter); Electron/React/TypeScript/Vitest/Playwright (desktop).

**Spec:** No written spec. The scope was approved in chat on 2026-10-26: the inventory list "cleanup proposal" sections 1–6. That approval excluded anything that overlaps the no-code desktop session.

## Repos and branches

- ruby_raider: `/Users/augustingottlieb/ruby_raider`, branch `feat/failure-video-replay`. Cleanup commits go on top of it.
- raider_reporter: `/Users/augustingottlieb/raider_reporter`, branch `feature/video-attachments`.
- raider_desktop: worktree `/Users/augustingottlieb/raider_desktop-parity-cleanup`, branch `feature/parity-cleanup`. It is based on the rebased `feature/video-player`, which is on top of origin/feature/14-quarantine 8fc5fb8.

## Global Constraints

- **Never touch** `/Users/augustingottlieb/raider_desktop` or `/Users/augustingottlieb/raider_desktop/.worktrees/*`. Another session owns them.
- **Desktop files owned by the other session.** Do NOT edit:
  - `src/main/handlers/{appState,getSuites,createSuite,deleteSuite,deleteTest,suitePersistence}.ts`
  - `project/setActiveProject.ts`, `project/projectLayout.ts`
  - `recording/*`
  - `io/{import*,export*,readDirectory}.ts`
  - `trace/*`, `testing/{runRecording,runSuite}.ts`, `handlers/tests/*`
  - `src/main/codegen/*`, `frameworkTemplates.ts`
  - `pages/Overview`, `pages/Recorder`
  - `components/{MainRecorderPanel,CommandList,CommandBlock,TestSuitePanel,ProjectTestsPanel}`
  - `Stores/{recorderStore,projectStore}`
  - e2e `recorder-page`, `recorder-controls`, `recorder-import-export`, `settings-recording`, `project-tests`
- **Shared desktop files:** `src/main/index.ts`, `preload/index.ts`, `foundation/Types/window.ts`, `en.json`, `e2e/helpers/navigation.ts`.
  - Deletions only, except the navigation helper change in Task 5.
  - In `en.json`, never edit keys under `recorder.*` or `overview.*`. Add only new top-level keys.
- **Gem files the other session's `feat/recorder-settings` branch changes.** Do NOT edit `web_config.tt`, `browser_helper.tt` or `helpers/partials/selenium_driver.tt`.
- **Keep** Capybara/Minitest *detection* (`projectLayout.ts`) and `test/integration/codegen/testFile.test.ts`.
- **Keep** the `refreshRecorderSettings` calls in `config/update{BrowserUrl,BrowserType,Headless,Timeout}.ts`.
- **Ruby versions:**
  - Minimum supported Ruby is 3.2.0 (gem `ruby_raider.gemspec:12` and reporter gemspec).
  - The desktop auto-install target is Ruby 3.4.1.
- **raider_reporter pin** in generated projects: `'~> 0.10'`.
- **No pushes, no publishing.** Stage files explicitly. Leave the user's untracked files alone.

## Review Focus

1. A desktop action that runs a gem command with a bad flag must surface an error, not a success toast. Covered by Tasks 1 and 4.
2. `raider new` with an unknown framework must exit non-zero with a clear message, not a NameError backtrace and exit 0. Task 1.
3. Users on Ruby 3.1 opening desktop must be told to upgrade (minimum 3.2.0). Task 6.
4. Cucumber "Re-run Failed" must re-run only the failed scenarios after a failing run in a freshly generated project. Task 2.
5. Removing Capybara/Minitest must not break opening a legacy Capybara/Minitest project. The detection is kept and the codegen test stays green. Task 5.

---

### Task 1: gem — non-zero exit on errors, remove dead Adopt

**Files:**
- Modify: `lib/ruby_raider.rb` and the Thor command classes in `lib/commands/*.rb`: add `def self.exit_on_failure? = true` (or the repo's Ruby style).
- Modify: `lib/generators/invoke_generators.rb`: validate `framework` (`rspec`, `cucumber`) and `automation` (`selenium`, `watir`, `appium`, `ios`, `android`, `cross_platform`). Use the values the menu actually accepts; confirm them in `menu_generator.rb`. An unknown value raises `Thor::Error` naming the bad key and the allowed values.
- Delete: `lib/commands/adopt_commands.rb`, `sig/commands/adopt_commands.rbs`. Also check `plugin_commands.rb`: if it is unregistered and dead, delete it and its sig the same way; if not, leave it.
- Test: `spec/commands/raider_commands_spec.rb`

- [ ] Step 1: failing specs, running `bin/raider` as a subprocess with Ruby 3.4.1 and gems installed:
  - `raider u debug on` → exit status ≠ 0, stderr includes `Could not find command "debug"`
  - `raider new x -p framework:minitest automation:selenium` → exit ≠ 0, output names `framework` and lists `rspec`, `cucumber`, and no directory `x` is created
  - `raider version` → exit 0
- [ ] Step 2: run them and see FAIL.
- [ ] Step 3: implement.
- [ ] Step 4: run `bundle exec rspec` on tracked spec files (exclude the user's untracked `spec/test_page_spec.rb`), rubocop on changed files, and `bundle exec steep check`. Expected: PASS. The known `azure_generator_spec.rb:75` failure predates this branch.
- [ ] Step 5: commit "Exit non-zero on CLI errors; validate new-project options; drop dead adopt command".

### Task 2: gem — Cucumber writes rerun.txt; reporter pin ~> 0.10

**Files:**
- Modify: `lib/generators/cucumber/templates/cucumber.tt` → `default: --format pretty --format rerun --out rerun.txt --publish-quiet --retry 0`
- Modify: the generated `.gitignore` template (find it) to ignore `rerun.txt`, if a gitignore is generated.
- Modify: `lib/generators/templates/common/gemfile.tt:16` → `gem 'raider_reporter', '~> 0.10'`
- Modify: README.md: remove the "0.9 still works" wording if present, and fix line 30 ("API backend" / "programmatic invocation" → CLI flags).
- Test: `spec/integration/content/cucumber_reporter_content_spec.rb` (or the cucumber.yml content spec), `gemfile_content_spec.rb`

- [ ] Step 1: failing content specs:
  - `cucumber.yml` includes `--format rerun --out rerun.txt`
  - Gemfile includes `gem 'raider_reporter', '~> 0.10'`
- [ ] Step 2: FAIL. Step 3: implement. Step 4: content specs pass.
- [ ] Step 5: run the cucumber e2e examples in `spec/integration/end_to_end_spec.rb` (the ones not tagged `:video`), so the rerun formatter doesn't break a real run.
- [ ] Step 6: commit "Write Cucumber rerun.txt and require raider_reporter 0.10 in generated projects".

### Task 3: reporter — docs match 0.10

**Files:**
- Modify: `docs/schema-v1.md:68`. Size caps become: 5 MB per non-video attachment, 50 MB per `video/*`; upload budget 45 MB and 1000 files, non-video first.
- Modify: `README.md`. Add `RAIDER_EXEC_SUMMARY` to the options table, with its meaning taken from `configuration.rb:23`.
- Modify: `examples/github_actions.yml`. Run tests the way generated CI does (`bundle exec raider-reporter exec -- …` if that is the generated form; check `ruby_raider/lib/generators/infrastructure/templates/github.tt`).
- [ ] Steps:
  1. Edit the three files.
  2. Run `bundle exec rspec`. Expected: 456+ pass.
  3. Commit "Document 0.10 size caps, exec summary and exec wrapper".

### Task 4: desktop — commands the gem accepts

**Files:**
- Modify: `src/main/handlers/config/updateBrowserOptions.ts`. Command becomes `raider u browser_options <each option, shell-quoted>`. With an empty list it becomes `raider u browser_options --delete`, if that clears; check `utility_commands.rb`.
- Delete:
  - `src/main/handlers/config/updateDebugMode.ts` and its IPC registration (`src/main/index.ts`)
  - its preload method and `window.ts` type
  - the `settings.debug` keys in `en.json`
  - its tests
- Modify:
  - `src/main/handlers/project/scaffoldGenerate.ts` and `src/shared/types/scaffoldTypes.ts`: keep only `generate <type> <name> [--path]` for `page|feature|spec|helper|steps|component|scaffold`. Drop `uses`, `from`, `ai`, `delete`, `dryRun`, `destroy`, `from_url` and `crud`.
  - `src/main/handlers/runRubyRaider.ts` and `src/shared/types/projectCreationTypes.ts`: drop `-r <reporter>`, `--skip_ci`, `--ruby_version` and their fields.
- Delete: `src/main/handlers/ruby/installRaider.ts`, its IPC, preload, `window.ts` entry and `ipcContract.test.ts` line.
- Test: unit tests next to each handler, following existing vitest patterns in `test/`.

- [ ] Step 1: failing vitest specs:
  - updateBrowserOptions builds `raider u browser_options no-sandbox 'window-size=1280,800'` (each arg quoted)
  - scaffoldGenerate for `{generate:'page', name:'login', path:'pages'}` builds `raider g page login --path pages`, and the type has no `crud`
  - runRubyRaider never emits `-r`, `--skip_ci` or `--ruby_version`
- [ ] Step 2: FAIL. Step 3: implement.
- [ ] Step 4: `npx vitest run`, `npm run typecheck`, `npx eslint <changed files>`. Expected: PASS.
- [ ] Step 5: commit "Send only commands and flags the raider gem accepts".

### Task 5: desktop — remove Capybara, Minitest and Adopt; fix stale e2e

**Files:**
- Delete: `src/renderer/src/components/Editor/completions/capybaraCompletions.ts`
- Modify:
  - `completions/registerProviders.ts`: remove the capybara and minitest branches and imports
  - `completions/testFrameworkCompletions.ts`: remove `registerMinitestCompletions`
  - `src/shared/types/raiderConfig.ts`: `automation` becomes `'Selenium' | 'Watir' | 'Appium'` (check what the gem's config writes and match case); `test` becomes `'Rspec' | 'Cucumber'`
- Modify: `test/integration/runRecording.test.ts`. Remove or retitle the minitest case only if it is not in the other session's ownership; `runRecording.ts` is theirs, but this test file isn't listed. If in doubt, leave it and note it.
- e2e:
  - delete `e2e/adopt-page.spec.ts` and `e2e/minitest-support.spec.ts`
  - remove `mockAdoptAnalyze` from `e2e/helpers/ipc-mock.ts`
  - `e2e/new-project-page.spec.ts`: drop the Capybara, Minitest, Appium/mobile and Applitools expectations, so the lists match `pages/New/index.tsx:16-19`
  - `e2e/app-launch.spec.ts`: expect the Welcome page ("Welcome to Ruby Raider!") as the start screen
  - `e2e/helpers/navigation.ts`: a helper that gets from the Welcome page into the main layout. Send the diff to the other session (`raider-desktop-e8`) before committing.
- Settings pages (agreed with the other session on 2026-10-26):
  - **Keep** `pages/ProjectSettings`; its Plan 4 will remount it. Only remove its debug toggle (Task 4 deletes `updateDebugMode`).
  - **Delete** `pages/RecorderSettings`, plus only the `en.json` `settings.*` keys that RecorderSettings uses alone. Before deleting a key, grep that ProjectSettings and everything else don't use it.
  - **Delete** e2e `settings-page.spec.ts` and `settings-project.spec.ts`.
  - **Do not touch** `settings-recording.spec.ts`.
- `e2e/helpers/ipc-mock.ts`: the other session is editing it now. Make only the `mockAdoptAnalyze` deletion.
- `e2e/app-launch.spec.ts`: change only the start-screen expectation. Overview's default tab is changing on the other branch, so assert nothing about Overview tabs.
- After committing, send the other session the exact diff for `ipc-mock.ts`, `app-launch.spec.ts` and `navigation.ts`.
- Test: the full e2e suite; record before and after pass counts (baseline on this branch: 97 passed, 91 failed).

- [ ] Step 1: make the removals.
- [ ] Step 2: run `npx vitest run`, `npm run typecheck` and `npx electron-vite build`.
- [ ] Step 3: run `npx playwright test`. Expected: no new failures. List every remaining failure with a one-line cause, marking which belong to the other session's specs.
- [ ] Step 4: commit, in two commits: "Remove Capybara, Minitest and Adopt from desktop", then "Update e2e for the Welcome start page".

### Task 6: desktop — Ruby 3.2 floor, 3.4.1 install

**Files:**
- Modify: `src/main/utils/rubyVersion.ts`: `MIN_MINOR = 2`
- Modify: `src/main/handlers/ruby/installRbenvAndRuby.ts`: 3.1.6 → 3.4.1 everywhere
- Modify: `isRubyInstalled.ts`, **version-floor edits only**. The other branch rewrote its command building in commit 2a3806f to use `src/main/utils/rubyCommand.ts` builders. Don't change any command string or shape in that file. If the floor check comes from `rubyVersion.ts`, leave this file untouched.
- Modify: `src/main/handlers/ruby/checkRubyDependencies.ts`: also check `watir`, following the existing pattern for the other gems. The other session offered this file to us.
- Modify: `en.json`: the install-guide strings that say "3.0.0 or higher" or "Ruby 3+" now say "3.2 or higher". Edit those keys only; they are not under recorder.* or overview.*.
- Test: `test/**/rubyVersion*.test.ts` (find or create)

- [ ] Step 1: failing tests: `isRubyVersionSufficient(3,1)` is false, `(3,2)` is true, and `formatMinimumVersion()` is `'3.2.0'`.
- [ ] Step 2: FAIL. Step 3: implement. Step 4: vitest and typecheck pass.
- [ ] Step 5: commit "Require Ruby 3.2 and install Ruby 3.4.1".

### Task 7: docs — desktop README and backend docs match the gem

**Files:**
- `README.md`:
  - Remove Capybara, Minitest and Adopt.
  - Set Ruby 3.2+.
  - Say new-project creates web projects only.
  - Remove claims for viewport presets and mobile capabilities if Task 5 deleted those pages; keep them if the pages stayed.
  - Explain that the version footer shows the globally installed gem.
  - Explain that failure video needs `RAIDER_FFMPEG_PATH` until the ffmpeg release exists, and where to see it (Project → Dashboard → failed card → Failure video).
  - Explain that desktop's "push to Longship" and raider_reporter's upload are separate paths.
  - Reconcile Windows: native win32 code exists, but the guide recommends WSL. State what is supported now, as the code shows.
- `BACKEND_PARITY.md` and `RUBY_RAIDER_INTEGRATION.md`: remove the gem surface that no longer exists:
  - `--visual`, `--performance`, `-r allure/junit/json`
  - `--skip_ci`, `--skip_allure`, `gitlab`
  - `g from_url`, `g destroy`, `--crud`, `--uses`, `--ai`
  - `u llm`, `u debug`, `raider pm`
  - Allure, Adopt, Capybara, Minitest

  Every remaining command and flag must exist in the gem's `lib/commands` and `lib/ruby_raider.rb`.
- `CLAUDE.md`: change "Ruby 3.0.0+" to "Ruby 3.2.0+".
- [ ] Steps:
  1. Edit the files.
  2. For each command example left in the two backend docs, check the gem accepts it, using `bin/raider help <cmd>` against the ruby_raider checkout.
  3. Commit "Align desktop docs with the raider gem".

### Task 8: desktop — Overview settings match the generated config

The other session handed these to us. It owns the Overview tab bar, the default tab and the Tests tab body, so stay away from those lines in `pages/Overview/index.tsx`.

**Files:**
- Modify: `pages/Overview/index.tsx`, scaffold/settings sections only:
  - The browser dropdown offers only `chrome` and `firefox` (around line 570). Generated config has `browser_arguments` for those two only.
  - Remove the "Custom Tag" run mode option and its `runRakeTask` path, keeping Smoke and Regression. Remove the `en.json` key `overview.settings.runMode.custom`; this is the one allowed deletion under `overview.*`, agreed with the other session.
  - The timeout initial value and the browser-options TagInput read back from the project config, not the `useState(30)` / empty defaults.
- Modify: `src/main/handlers/config/getProjectConfig.ts`: also return `timeout` (number) and `browserArguments` (string[] for the current browser), read from `config/config.yml`. That is `config.timeout` and `config.browser_arguments[config.browser]`.
- Test: the unit test for `getProjectConfig` (find or create): given a config.yml with `timeout: 10`, `browser: chrome`, and `browser_arguments: {chrome: [no-sandbox]}`, it returns `timeout: 10` and `browserArguments: ['no-sandbox']`. Add a renderer test for the Overview settings, if one exists, asserting the browser options are exactly Chrome and Firefox.
- [ ] Steps:
  1. Write the failing tests.
  2. Implement.
  3. Run vitest, typecheck and eslint on the changed files.
  4. Commit "Show the project's real timeout and browser args; offer only supported browsers".

## Not in this plan
- These are the other session's (recorder area):
  - recorder export, Watir recording, recorded runs outside the project, the wait keys
- After this plan is done, ask the user again about the next parity item. That is item #2: steps, stdout and retries in run.json.
