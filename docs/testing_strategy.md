# Ruby Raider Testing Strategy

## Overview

Ruby Raider uses a **comprehensive 3-level testing strategy** to ensure generated test automation frameworks work correctly:

1. **Unit Tests** - Fast, focused tests for individual components
2. **Integration Tests** - Verify project generation and file structure
3. **End-to-End Tests** - Validate generated projects actually execute

This multi-layered approach catches bugs at different levels and provides confidence that users receive working, executable test frameworks.

---

## Level 1: Unit Tests

**Purpose:** Test individual components in isolation

**Location:** `spec/generators/template_renderer_spec.rb`

**What they test:**
- TemplateRenderer module functionality
- PartialCache caching behavior and mtime invalidation
- PartialResolver path resolution (relative + fallback)
- Custom error classes (TemplateNotFoundError, TemplateRenderError)
- Integration with Generator base class

**Speed:** < 1 second

**When to run:** During development, after every change

**Example:**
```ruby
describe TemplateRenderer do
  it 'caches compiled ERB objects' do
    result1 = generator.partial('screenshot')
    result2 = generator.partial('screenshot')

    expect(Generator.template_cache_stats[:size]).to be > 0
  end
end
```

**Run command:**
```bash
bundle exec rspec spec/generators/template_renderer_spec.rb
```

---

## Level 2: Integration Tests

**Purpose:** Verify projects generate with correct structure

**Location:** `spec/integration/generators/*_spec.rb`

**What they test:**
- All framework combinations generate successfully
- Required files are created (helpers, specs, features, config)
- File structure matches expected layout
- Generated Ruby files have valid syntax
- CI/CD files are generated correctly

**Coverage:**
- 7 automation types × 2 frameworks × 3 CI platforms = **42 combinations**
- Selenium, Watir, Appium (iOS, Android, cross-platform), Axe, Applitools
- RSpec and Cucumber
- GitHub Actions, GitLab CI, no CI

**Speed:** 2-3 seconds

**When to run:** Before committing changes

**Example:**
```ruby
describe 'Selenium + RSpec' do
  it 'creates a driver helper file' do
    expect(File).to exist('rspec_selenium/helpers/driver_helper.rb')
  end

  it 'creates spec files' do
    expect(File).to exist('rspec_selenium/spec/login_page_spec.rb')
  end
end
```

**Run command:**
```bash
# Run all integration tests
bundle exec rspec spec/integration/ --tag ~slow

# Run specific generator tests
bundle exec rspec spec/integration/generators/helpers_generator_spec.rb
```

---

## Level 3: End-to-End Tests

**Purpose:** Validate generated projects are **executable and functional**

**Location:** `spec/integration/end_to_end_spec.rb`

**What they test:**
- Generated projects install dependencies successfully (`bundle install`)
- Generated tests run without errors (`bundle exec rspec`)
- Generated tests pass (exit code 0)
- Template rendering produces working code, not just syntactically valid code

**Coverage:**

| Framework | Test Type | Notes |
|-----------|-----------|-------|
| Selenium + RSpec | **Full execution** | Tests run in generated project |
| Watir + RSpec | **Full execution** | Tests run in generated project |
| Selenium + Cucumber | **Full execution** | Features run in generated project |
| Watir + Cucumber | **Full execution** | Features run in generated project |
| Axe + Cucumber | **Full execution** | Accessibility tests run |
| iOS + RSpec | Structure validation | Requires Appium server |
| Android + Cucumber | Structure validation | Requires Appium server |
| Cross-Platform + RSpec | Structure validation | Requires Appium server |
| Applitools + RSpec | Structure validation | Requires API key |

**Speed:** 5-10 minutes (due to bundle install + test execution)

**When to run:**
- Before releasing new versions
- After major template changes
- In CI/CD before merging PRs

**How it works:**

```ruby
describe 'Selenium + RSpec' do
  it 'runs generated RSpec tests successfully' do
    project_name = 'rspec_selenium'

    # Step 1: Verify project structure
    expect(File).to exist("#{project_name}/Gemfile")
    expect(File).to exist("#{project_name}/spec")

    # Step 2: Install dependencies
    result = run_in_project(project_name, 'bundle install --quiet')
    expect(result[:success]).to be true

    # Step 3: Run generated tests
    result = run_in_project(project_name, 'bundle exec rspec')

    # Step 4: Assert tests passed
    expect(result[:success]).to be(true),
      "RSpec tests failed:\n#{result[:stdout]}\n#{result[:stderr]}"
  end
end
```

**Run command:**
```bash
# Run all end-to-end tests
bundle exec rspec spec/integration/end_to_end_spec.rb --format documentation

# Run specific framework
bundle exec rspec spec/integration/end_to_end_spec.rb:130
```

---

## Test Helpers

### `run_in_project(project_name, command, timeout: 300)`

Executes a shell command inside a generated project directory.

**Parameters:**
- `project_name` - Name of generated project directory
- `command` - Shell command to run (e.g., `bundle install`)
- `timeout` - Maximum seconds to wait (default: 300)

**Returns:**
```ruby
{
  success: true/false,     # Whether command succeeded
  stdout: "output...",     # Standard output
  stderr: "errors...",     # Standard error
  exit_code: 0             # Process exit code
}
```

**Usage:**
```ruby
# Install dependencies
result = run_in_project('rspec_selenium', 'bundle install')
expect(result[:success]).to be true

# Run tests
result = run_in_project('rspec_selenium', 'bundle exec rspec --format json')
json = JSON.parse(result[:stdout])
expect(json['summary']['failure_count']).to eq(0)
```

### `bundle_install(project_name)`

Convenience wrapper for installing dependencies.

**Returns:** `true` if successful, `false` otherwise

**Usage:**
```ruby
it 'installs dependencies' do
  expect(bundle_install('rspec_selenium')).to be true
end
```

### `run_rspec(project_name)`

Runs RSpec tests in generated project with formatted output.

**Returns:** Hash with `:success`, `:stdout`, `:stderr`, `:exit_code`

**Usage:**
```ruby
it 'runs RSpec tests' do
  result = run_rspec('rspec_selenium')
  expect(result[:success]).to be true
  expect(result[:stdout]).to include('0 failures')
end
```

### `run_cucumber(project_name)`

Runs Cucumber features in generated project.

**Returns:** Hash with `:success`, `:stdout`, `:stderr`, `:exit_code`

**Usage:**
```ruby
it 'runs Cucumber features' do
  result = run_cucumber('cucumber_selenium')
  expect(result[:success]).to be true
  expect(result[:stdout]).to include('0 failed')
end
```

---

## Adding Tests for New Features

### When Adding a New Generator

1. **Add unit tests** (if generator has complex logic)
   ```ruby
   # spec/generators/my_generator_spec.rb
   describe MyGenerator do
     it 'generates expected files' do
       # Test generator logic
     end
   end
   ```

2. **Add integration tests** for file structure
   ```ruby
   # spec/integration/generators/my_generator_spec.rb
   describe MyGenerator do
     it 'creates required files' do
       expect(File).to exist('my_framework/my_file.rb')
     end
   end
   ```

3. **Add end-to-end test** if framework is executable
   ```ruby
   # spec/integration/end_to_end_spec.rb
   describe 'My Framework' do
     include_examples 'executable rspec project', 'my_framework'
   end
   ```

### When Modifying Templates

1. **Verify unit tests pass** (template rendering works)
   ```bash
   bundle exec rspec spec/generators/template_renderer_spec.rb
   ```

2. **Verify integration tests pass** (structure correct)
   ```bash
   bundle exec rspec spec/integration/ --tag ~slow
   ```

3. **Verify end-to-end tests pass** (generated code works)
   ```bash
   bundle exec rspec spec/integration/end_to_end_spec.rb
   ```

4. **Manual smoke test** on one framework
   ```bash
   bin/raider new smoke_test -p framework:rspec automation:selenium
   cd smoke_test && bundle install && bundle exec rspec
   ```

---

## CI/CD Integration

### GitHub Actions Workflow

**File:** `.github/workflows/end_to_end.yml`

```yaml
name: End-to-End Tests

on:
  pull_request:
    branches: [master, main]
  push:
    branches: [master, main]

jobs:
  unit-and-integration:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ['3.1', '3.2', '3.3']

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby-version }}
          bundler-cache: true

      - name: Run unit tests
        run: bundle exec rspec spec/generators/

      - name: Run integration tests
        run: bundle exec rspec spec/integration/ --tag ~slow

  end-to-end:
    runs-on: ubuntu-latest
    needs: unit-and-integration

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Run end-to-end tests
        run: |
          bundle exec rspec spec/integration/end_to_end_spec.rb \
            --format documentation \
            --format json \
            --out e2e_results.json

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: e2e-test-results
          path: e2e_results.json
```

### GitLab CI Pipeline

**File:** `.gitlab-ci.yml`

```yaml
stages:
  - test
  - e2e

variables:
  RBENV_VERSION: "3.3.0"

unit_and_integration_tests:
  stage: test
  script:
    - bundle install
    - bundle exec rspec spec/generators/
    - bundle exec rspec spec/integration/ --tag ~slow
  artifacts:
    reports:
      junit: rspec.xml

end_to_end_tests:
  stage: e2e
  needs: [unit_and_integration_tests]
  script:
    - bundle install
    - bundle exec rspec spec/integration/end_to_end_spec.rb --format documentation
  timeout: 15 minutes
  artifacts:
    when: always
    paths:
      - rspec_selenium/
      - cucumber_watir/
    expire_in: 1 day
```

---

## Troubleshooting

### End-to-End Test Failures

**Problem:** Test fails with "bundle install failed"

**Solutions:**
- Check Gemfile.lock compatibility with Ruby version
- Verify all dependencies are available on RubyGems
- Check for platform-specific gems (e.g., nokogiri on Windows)

**Problem:** Generated tests fail to run

**Solutions:**
- Check generated test file syntax: `ruby -c spec/login_page_spec.rb`
- Verify helper files are being required correctly
- Check RSpec/Cucumber configuration files

**Problem:** Tests timeout

**Solutions:**
- Increase timeout in test (default: 300 seconds)
- Check if command is hanging (e.g., waiting for user input)
- Verify bundle install isn't prompting for credentials

### Common Issues

**Issue:** "Partial 'xyz' not found"

**Cause:** Template path resolution failed

**Fix:**
- Check partial exists in `partials/` subdirectory
- Verify Generator.source_paths includes template directory
- Check for typos in partial name

**Issue:** "Generated project has syntax errors"

**Cause:** Template rendering produced invalid Ruby code

**Fix:**
- Run `ruby -c` on generated file to identify error
- Check ERB syntax in template
- Verify binding context has required variables/methods

---

## Performance Benchmarks

### Test Suite Execution Times

| Test Type | Duration | Frequency |
|-----------|----------|-----------|
| Unit Tests | < 1 second | Every change |
| Integration Tests | 2-3 seconds | Before commit |
| End-to-End Tests | 5-10 minutes | Before release |

### What Makes E2E Tests Slow?

- **Bundle install:** 60-120 seconds per project (downloads gems)
- **Test execution:** 30-60 seconds per project (runs actual tests)
- **Multiple frameworks:** 5 web frameworks × 2 minutes = 10 minutes total

### Optimization Strategies

1. **Parallel execution** - Run framework tests concurrently
   ```bash
   bundle exec rspec spec/integration/end_to_end_spec.rb --tag selenium &
   bundle exec rspec spec/integration/end_to_end_spec.rb --tag watir &
   wait
   ```

2. **Shared bundle cache** - Reuse installed gems
   ```ruby
   ENV['BUNDLE_PATH'] = '/tmp/bundle_cache'
   ```

3. **Skip slow tests locally** - Only run in CI
   ```bash
   bundle exec rspec --tag ~slow  # Skip end-to-end tests
   ```

---

## Best Practices

### Writing Good End-to-End Tests

✅ **DO:**
- Test happy path (basic functionality works)
- Verify exit codes (0 = success)
- Include stdout/stderr in failure messages
- Use appropriate timeouts (bundle install = 180s, tests = 120s)
- Clean up generated projects after tests

❌ **DON'T:**
- Test edge cases (use unit tests for that)
- Make external API calls (use mocks/stubs)
- Hardcode file paths (use relative paths)
- Ignore test output (always print on failure)
- Leave generated projects after test run

### Test Organization

```
spec/
├── generators/              # Unit tests
│   └── template_renderer_spec.rb
├── integration/
│   ├── spec_helper.rb      # Shared setup
│   ├── generators/         # Integration tests (structure)
│   │   ├── helpers_generator_spec.rb
│   │   ├── automation_generator_spec.rb
│   │   └── ...
│   └── end_to_end_spec.rb  # End-to-end tests (execution)
```

### Naming Conventions

- **Unit tests:** `component_name_spec.rb`
- **Integration tests:** `generator_name_spec.rb`
- **End-to-end tests:** `end_to_end_spec.rb` (single file)

---

## Metrics & Reporting

### Test Coverage

Current coverage (as of v1.2.0):

- **Unit tests:** 30 examples, 0 failures
- **Integration tests:** 213 examples, 0 failures
- **End-to-end tests:** 19 examples, 0 failures (web frameworks)

**Total:** 262 examples across all levels

### Success Criteria

Before releasing a new version, ensure:

- [ ] All unit tests pass (100%)
- [ ] All integration tests pass (100%)
- [ ] All end-to-end web framework tests pass (100%)
- [ ] Mobile framework structure validation passes
- [ ] Manual smoke test successful on 2+ frameworks
- [ ] No RuboCop offenses
- [ ] No Reek code smells (allowed suppressions only)

---

## Future Enhancements

### Potential Improvements

1. **Docker-based E2E tests** - Include Appium/Selenium Grid
2. **Visual regression testing** - Screenshot comparison
3. **Performance benchmarks** - Track generation speed over time
4. **Parallel test execution** - Run frameworks concurrently
5. **Test result dashboard** - Visualize test trends
6. **Mutation testing** - Verify test quality

### Adding Mobile E2E Tests

To enable full execution of mobile framework tests:

1. Set up Appium server in CI
2. Configure iOS simulator / Android emulator
3. Update end-to-end spec to run mobile tests
4. Add timeout handling for device startup

**Example:**
```ruby
describe 'iOS + RSpec', :mobile do
  before(:all) do
    start_appium_server
    start_ios_simulator
  end

  it 'runs generated tests on iOS simulator' do
    result = run_rspec('rspec_ios')
    expect(result[:success]).to be true
  end
end
```

---

## Resources

- **RSpec Documentation:** https://rspec.info
- **Thor Documentation:** http://whatisthor.com
- **Open3 Documentation:** https://ruby-doc.org/stdlib-3.1.0/libdoc/open3/rdoc/Open3.html
- **Ruby Raider Website:** https://ruby-raider.com

---

**Last Updated:** 2026-02-10
**Version:** 1.2.0 (Template System Refactoring)
