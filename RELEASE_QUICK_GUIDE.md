# Quick Release Guide

## TL;DR - One Command Release

```bash
# Bug fixes: 1.1.4 -> 1.1.5
bin/release patch

# New features: 1.1.4 -> 1.2.0
bin/release minor

# Breaking changes: 1.1.4 -> 2.0.0
bin/release major
```

**Everything else is automated!**

---

## What Happens

1. ✅ Script validates & tests locally
2. ✅ Updates version in `lib/version`
3. ✅ Creates git commit + tag
4. ✅ Pushes to GitHub
5. ✅ GitHub Actions automatically:
   - Runs tests
   - Builds gem
   - Publishes to RubyGems
   - Creates GitHub Release

**Duration:** ~3 minutes total

---

## Before Releasing

Ensure:
- [ ] All changes merged to master
- [ ] Tests passing: `bundle exec rspec`
- [ ] Linters passing: `bundle exec rubocop && bundle exec reek`

---

## Monitor Progress

**GitHub Actions:**
https://github.com/RubyRaider/ruby_raider/actions

**GitHub Releases:**
https://github.com/RubyRaider/ruby_raider/releases

**RubyGems:**
https://rubygems.org/gems/ruby_raider

---

## First-Time Setup

Add RubyGems API key to GitHub Secrets:

1. Get API key:
   ```bash
   gem signin
   # Visit https://rubygems.org/profile/edit
   # Copy API key
   ```

2. Add to GitHub:
   - Go to: Settings → Secrets → Actions
   - Add `RUBYGEMS_API_KEY` secret

---

## Full Documentation

See [RELEASE.md](RELEASE.md) for complete documentation.
