# Release Process Documentation

## Release Notes

### 3.7.0

- Generated RSpec projects no longer include Allure: the `allure-rspec` and `allure-ruby-commons` gems, `helpers/allure_helper.rb`, the `allure-results` folder and `.gitignore` entry, and the Allure report and gh-pages steps in the GitHub Actions workflow are gone. `raider_reporter` is now the only reporter.
- Generated Gemfiles now require `raider_reporter` `~> 0.7`, which writes a browsable `raider-results/index.html` next to `run.json`; `bundle exec raider-reporter report` rebuilds it.
- The generated Readme's Reporting section points to the local HTML report; failure screenshots are attached to the report and to Raider.
- The unused `test_helper` and `video_stop` templates (Allure-only) are removed.

### 3.6.0

- New `ci` parameter: `raider new my_project -p framework:rspec automation:selenium ci:azure` generates an `azure-pipelines.yml` for web projects instead of the GitHub Actions workflow. `ci:github` (the default) is unchanged; any other value fails with `Invalid parameters: ci must be github or azure`.
- The pipeline runs the suite on `ubuntu-latest`, publishes `raider-results/` as a pipeline artifact and includes a `raider_comment` job that comments Raider results on pull requests via `raider-reporter comment`. It needs the `RAIDER_TOKEN` (secret) and `RAIDER_ENDPOINT` pipeline variables and the "Contribute to pull requests" permission for the build service.
- Azure Repos ignores `pr:` triggers: add the pipeline as a Build validation branch policy so pull request builds and the Raider comment run.
- The interactive menu asks "Which CI provider?" (GitHub Actions / Azure Pipelines) for web automations.
- The generated Readme gets an "Azure Pipelines" section when `ci:azure` is used.
- Mobile projects with `ci:azure` get no pipeline file yet; `raider new` prints a notice.
- Generated Gemfiles now require `raider_reporter` `~> 0.5`.

### 3.5.0

- Generated Cucumber projects now report through `raider_reporter` `~> 0.4` instead of Allure: results are written to `raider-results/` and uploaded when `RAIDER_TOKEN` and `RAIDER_ENDPOINT` are set. The reporter is activated by `require 'raider_reporter/cucumber'` in `features/support/env.rb`.
- Cucumber projects no longer include `allure-cucumber` or `helpers/allure_helper.rb`; failure screenshots are attached to Raider only, and `.gitignore` lists `raider-results` instead of `allure-results`.
- Generated Cucumber GitHub CI now passes the Raider settings to the test run, uploads `raider-results/` as an artifact and includes the `raider-comment` job, matching RSpec projects. The Allure report and gh-pages steps are removed for Cucumber. RSpec pipelines are unchanged.
- The generated Readme has a "Reporting" section for Cucumber projects too.
- Generated Gemfiles now require `raider_reporter` `~> 0.4`.

### 3.4.0

- Generated RSpec projects with GitHub CI now include a `raider-comment` job that comments Raider test results on pull requests via `raider-reporter comment`. It runs after every test job, only on pull requests, and needs the `RAIDER_TOKEN` secret and `RAIDER_ENDPOINT` variable. Cucumber projects are unchanged.
- The job needs `contents: read`, `pull-requests: write` and `statuses: write` permissions; it reports a `raider/tests` status, and pull requests from forks are skipped.
- Generated Gemfiles now require `raider_reporter` `~> 0.3`.
- Ruby Raider now requires Ruby 3.2.0 or newer.

### 3.3.0

- Generated RSpec projects now include `raider_reporter`: results are written to `raider-results/` and uploaded when `RAIDER_TOKEN` and `RAIDER_ENDPOINT` are set. Allure is still produced. Cucumber projects are unchanged.
- Screenshots (Allure too) are now taken only when an example fails, and are attached to both Allure and Raider.
- Generated GitHub CI now runs on push (main, master), pull requests and manual dispatch, passes the Raider settings to RSpec runs and uploads `raider-results/` as an artifact.
- Fixed the generated Gemfile `ruby_raider` pin so it follows the gem's own major.minor version.

---

## Overview

Ruby Raider uses a **fully automated release process**. You only need to run a single command, and everything else happens automatically via GitHub Actions.

## Prerequisites

Before releasing, ensure you have:

1. ✅ Merged all changes to `master` branch
2. ✅ All tests passing locally
3. ✅ RuboCop and Reek checks passing
4. ✅ GitHub repository configured with secrets:
   - `RUBYGEMS_API_KEY` - RubyGems API key for publishing

## One-Command Release

```bash
# For bug fixes (1.1.4 -> 1.1.5)
bin/release patch

# For new features (1.1.4 -> 1.2.0)
bin/release minor

# For breaking changes (1.1.4 -> 2.0.0)
bin/release major
```

That's it! Everything else is automated.

---

## What Happens Automatically

### 1. Local Checks (bin/release script)

The release script will:
- ✅ Verify working directory is clean
- ✅ Confirm you're on master/main branch
- ✅ Run all unit tests
- ✅ Run integration tests
- ✅ Run RuboCop linter
- ✅ Run Reek code smell detector
- ✅ Calculate new version number
- ✅ Ask for confirmation
- ✅ Update `lib/version` file
- ✅ Create git commit with version bump
- ✅ Create git tag (e.g., `v1.2.0`)
- ✅ Push commit and tag to GitHub

**If any step fails, the release is aborted.**

### 2. GitHub Actions Workflow (Triggered by Tag)

When the tag is pushed, the `.github/workflows/release.yml` workflow:

**Validation Phase:**
- ✅ Verifies version in `lib/version` matches tag
- ✅ Runs all tests again (unit + integration)
- ✅ Runs RuboCop
- ✅ Runs Reek

**Build Phase:**
- ✅ Builds the gem (`ruby_raider-X.Y.Z.gem`)

**Release Phase:**
- ✅ Generates changelog from git commits
- ✅ Creates GitHub Release with:
  - Release notes
  - Changelog
  - Gem file attachment
- ✅ Publishes gem to RubyGems.org

**All of this happens automatically within 2-3 minutes.**

---

## Example Release Flow

```bash
$ bin/release minor

🧪 Running tests...
......................................

✓ All tests and linters passed

📦 Release Summary
  Current version: 1.1.4
  New version:     1.2.0
  Bump type:       minor

This will:
  1. Update lib/version to 1.2.0
  2. Commit changes
  3. Create git tag v1.2.0
  4. Push to GitHub (triggers automated release)
  5. Publish gem to RubyGems (via GitHub Actions)
  6. Create GitHub release with changelog

Proceed with release? [y/N] y

📝 Updating version to 1.2.0...
✓ Updated lib/version

📌 Creating commit and tag...
✓ Created commit and tag v1.2.0

🚀 Pushing to GitHub...
✓ Pushed to GitHub

============================================================
🎉 Release 1.2.0 initiated successfully!
============================================================

The GitHub Actions workflow is now:
  1. Running tests
  2. Building the gem
  3. Publishing to RubyGems
  4. Creating GitHub release

Monitor progress at:
  https://github.com/RubyRaider/ruby_raider/actions

Release will be available at:
  https://github.com/RubyRaider/ruby_raider/releases/tag/v1.2.0
  https://rubygems.org/gems/ruby_raider/versions/1.2.0

✨ Thank you for contributing to Ruby Raider!
```

---

## Semantic Versioning Guide

Ruby Raider follows [Semantic Versioning](https://semver.org/):

### Patch Release (X.Y.Z+1)

**When:** Bug fixes, small improvements, no new features

**Examples:**
- Fix template rendering bug
- Update documentation
- Performance improvements
- Dependency updates

**Command:**
```bash
bin/release patch  # 1.1.4 -> 1.1.5
```

### Minor Release (X.Y+1.0)

**When:** New features, backward-compatible changes

**Examples:**
- Add new framework support
- New template system
- New CLI commands
- Enhanced functionality

**Command:**
```bash
bin/release minor  # 1.1.4 -> 1.2.0
```

### Major Release (X+1.0.0)

**When:** Breaking changes, major refactors

**Examples:**
- Drop Ruby 2.x support
- Change public API
- Remove deprecated features
- Architectural changes

**Command:**
```bash
bin/release major  # 1.1.4 -> 2.0.0
```

---

## Monitoring the Release

### 1. GitHub Actions Progress

Visit: https://github.com/RubyRaider/ruby_raider/actions

You'll see the "Automated Release" workflow running with steps:
- ✅ Checkout code
- ✅ Run tests
- ✅ Build gem
- ✅ Generate changelog
- ✅ Create GitHub Release
- ✅ Publish to RubyGems

**Expected duration:** 2-3 minutes

### 2. GitHub Release

Visit: https://github.com/RubyRaider/ruby_raider/releases

You'll see the new release with:
- Version number
- Changelog (auto-generated from commits)
- Gem file download
- Installation instructions

### 3. RubyGems.org

Visit: https://rubygems.org/gems/ruby_raider

The new version will appear within 1-2 minutes of publication.

---

## Troubleshooting

### Problem: "Working directory is not clean"

**Solution:** Commit or stash your changes first
```bash
git status
git add .
git commit -m "Your changes"
# Then try release again
```

### Problem: "Tests failed"

**Solution:** Fix the failing tests before releasing
```bash
bundle exec rspec
bundle exec rubocop --auto-correct
bundle exec reek
```

### Problem: "Version mismatch in workflow"

**Solution:** This means `lib/version` doesn't match the tag

This should never happen if using `bin/release`, but if it does:
```bash
# Check version
cat lib/version

# Update manually
echo "1.2.0" > lib/version
git add lib/version
git commit -m "Fix version"
git push
```

### Problem: "RubyGems API key not configured"

**Solution:** Add the secret in GitHub:

1. Get your RubyGems API key:
   ```bash
   curl -u your-rubygems-username https://rubygems.org/api/v1/api_key.yaml
   ```

2. Add to GitHub Secrets:
   - Go to: https://github.com/RubyRaider/ruby_raider/settings/secrets/actions
   - Click "New repository secret"
   - Name: `RUBYGEMS_API_KEY`
   - Value: (paste your API key)
   - Click "Add secret"

### Problem: "Failed to push to GitHub"

**Solution:** Check your authentication
```bash
# Test push access
git push origin master

# If using HTTPS, you may need a personal access token
# If using SSH, ensure your key is added
```

---

## Manual Release (Backup Method)

If the automated system fails, you can release manually:

```bash
# 1. Update version
echo "1.2.0" > lib/version

# 2. Commit
git add lib/version
git commit -m "Bump version to 1.2.0"

# 3. Create tag
git tag -a v1.2.0 -m "Release version 1.2.0"

# 4. Push
git push origin master
git push origin v1.2.0

# 5. Build gem
gem build ruby_raider.gemspec

# 6. Push to RubyGems
gem push ruby_raider-1.2.0.gem

# 7. Create GitHub Release manually
# Visit: https://github.com/RubyRaider/ruby_raider/releases/new
```

---

## Release Checklist

Before releasing, verify:

- [ ] All PRs merged to master
- [ ] CHANGELOG or commit messages are clear
- [ ] Tests passing locally (`bundle exec rspec`)
- [ ] RuboCop passing (`bundle exec rubocop`)
- [ ] Reek passing (`bundle exec reek`)
- [ ] Version bump type is correct (patch/minor/major)
- [ ] GitHub Actions secrets configured (RUBYGEMS_API_KEY)

Then run:

```bash
bin/release [patch|minor|major]
```

And monitor at:
- https://github.com/RubyRaider/ruby_raider/actions

---

## Post-Release

After a successful release:

1. ✅ Verify gem on RubyGems: https://rubygems.org/gems/ruby_raider
2. ✅ Check GitHub Release: https://github.com/RubyRaider/ruby_raider/releases
3. ✅ Test installation:
   ```bash
   gem install ruby_raider -v 1.2.0
   raider --version
   ```
4. ✅ Announce release (Twitter, Discord, etc.)
5. ✅ Update website if needed

---

## Configuration Files

### Release Workflow
- **File:** `.github/workflows/release.yml`
- **Trigger:** Push of tag matching `v*.*.*`
- **Actions:** Test → Build → Release → Publish

### Release Script
- **File:** `bin/release`
- **Usage:** `bin/release [major|minor|patch]`
- **Purpose:** Local validation and version bumping

### Version File
- **File:** `lib/version`
- **Format:** Single line with version number (no 'v' prefix)
- **Example:** `1.2.0`

---

## FAQ

**Q: Can I release from a branch?**
A: The script will warn you. It's recommended to release from master/main only.

**Q: Can I skip tests?**
A: No. Tests are mandatory for releases to ensure quality.

**Q: How do I rollback a release?**
A: You can't unpublish from RubyGems, but you can:
1. Yank the version: `gem yank ruby_raider -v X.Y.Z`
2. Release a new patch version with fixes

**Q: What if the GitHub Actions workflow fails?**
A: Check the logs, fix the issue, delete the tag, and try again:
```bash
git tag -d v1.2.0
git push origin :refs/tags/v1.2.0
# Fix issue, then re-run bin/release
```

**Q: How long does a release take?**
A: ~2-3 minutes from pushing the tag to gem being available on RubyGems.

---

## Support

If you encounter issues with the release process:

1. Check the [troubleshooting section](#troubleshooting)
2. Review GitHub Actions logs
3. Open an issue: https://github.com/RubyRaider/ruby_raider/issues

---

**Last Updated:** 2026-02-10
**Automation Version:** 1.0
