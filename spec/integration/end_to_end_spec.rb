# frozen_string_literal: true

require_relative 'spec_helper'
require 'timeout'
require 'open3'
require 'json'

# End-to-end integration tests that verify generated projects actually work
# These tests:
# 1. Generate a complete project
# 2. Install dependencies (bundle install)
# 3. Run the generated tests (rspec/cucumber)
# 4. Verify tests pass
#
# This ensures the template system produces working, executable test frameworks
describe 'End-to-End Project Generation and Execution' do
  # Helper to run commands in a generated project directory
  def run_in_project(project_name, command, timeout: 300)
    result = {
      success: false,
      stdout: '',
      stderr: '',
      exit_code: nil
    }

    Dir.chdir(project_name) do
      Bundler.with_unbundled_env do
        Timeout.timeout(timeout) do
          stdout, stderr, status = Open3.capture3(command)
          result[:stdout] = stdout
          result[:stderr] = stderr
          result[:exit_code] = status.exitstatus
          result[:success] = status.success?
        end
      end
    end

    result
  rescue Timeout::Error
    result[:stderr] = "Command timed out after #{timeout} seconds"
    result[:exit_code] = -1
    result
  end

  # The generated Gemfile pins ruby_raider to this gem's major.minor, which may not be
  # published yet (a release candidate branch). Resolve it from this checkout instead;
  # the pin itself is covered by the Gemfile content specs.
  def use_local_ruby_raider(project_name)
    gemfile = File.join(project_name, 'Gemfile')
    root = File.expand_path('../..', __dir__)
    File.write(gemfile, File.read(gemfile).sub(/^gem 'ruby_raider'.*$/, "gem 'ruby_raider', path: '#{root}'"))
  end

  # Helper to install dependencies
  def bundle_install(project_name)
    puts "\n📦 Installing dependencies for #{project_name}..."
    use_local_ruby_raider(project_name)
    result = run_in_project(project_name, 'bundle install --quiet', timeout: 180)

    unless result[:success]
      puts '❌ Bundle install failed:'
      puts result[:stderr]
      puts result[:stdout]
    end

    result[:success]
  end

  # Helper to run RSpec tests
  def run_rspec(project_name)
    puts "\n🧪 Running RSpec tests in #{project_name}..."
    result = run_in_project(project_name, 'bundle exec rspec spec/ --format documentation', timeout: 120)

    puts result[:stdout] if result[:stdout].length.positive?

    unless result[:success]
      puts '❌ RSpec tests failed:'
      puts result[:stderr] if result[:stderr].length.positive?
    end

    result
  end

  # Helper to run Cucumber tests
  def run_cucumber(project_name)
    puts "\n🥒 Running Cucumber tests in #{project_name}..."
    result = run_in_project(project_name, 'HEADLESS=true bundle exec cucumber features/ --format pretty', timeout: 120)

    puts result[:stdout] if result[:stdout].length.positive?

    unless result[:success]
      puts '❌ Cucumber tests failed:'
      puts result[:stderr] if result[:stderr].length.positive?
    end

    result
  end

  # Shared example for RSpec-based projects
  shared_examples 'executable rspec project' do |project_name|
    let(:project) { project_name }

    it 'installs dependencies successfully' do
      expect(bundle_install(project)).to be true
    end

    it 'resolves raider_reporter 0.9 from RubyGems and ships the raider-reporter executable', :aggregate_failures do
      skip 'Bundle install failed' unless bundle_install(project)

      expect(File.read(File.join(project, 'Gemfile.lock'))).to match(/^    raider_reporter \(0\.9\.\d+\)$/)
      result = run_in_project(project, 'bundle exec raider-reporter --help', timeout: 60)
      expect(result[:exit_code]).to eq(0), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
      expect(result[:stdout] + result[:stderr]).to include('raider-reporter comment')
    end

    it 'runs generated RSpec tests successfully', :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      result = run_rspec(project)

      expect(result[:success]).to be(true),
                                  "RSpec tests failed with exit code #{result[:exit_code]}.\n" \
                                  "STDOUT: #{result[:stdout]}\n" \
                                  "STDERR: #{result[:stderr]}"
    end

    it 'writes raider-results/run.json listing every example without changing the exit status', :aggregate_failures, :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      FileUtils.rm_rf(File.join(project, 'raider-results'))
      result = run_rspec(project)
      summary = result[:stdout].match(/(\d+) examples?, (\d+) failures?/)
      expect(summary).not_to be_nil, "No RSpec summary line.\nSTDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
      examples = summary[1].to_i
      failures = summary[2].to_i

      run_file = File.join(project, 'raider-results', 'run.json')
      expect(File).to exist(run_file)
      run = JSON.parse(File.read(run_file))
      expect(run['schema_version']).to eq(1)
      expect(run['results'].size).to eq(examples)
      expect(run['results'].count { |r| r['status'] == 'failed' }).to eq(failures)
      expect(result[:exit_code]).to eq(failures.zero? ? 0 : 1)
    end
  end

  # Shared example for Cucumber-based projects
  shared_examples 'executable cucumber project' do |project_name|
    let(:project) { project_name }

    it 'installs dependencies successfully' do
      expect(bundle_install(project)).to be true
    end

    it 'runs generated Cucumber tests successfully', :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      result = run_cucumber(project)

      expect(result[:success]).to be(true),
                                  "Cucumber tests failed with exit code #{result[:exit_code]}.\n" \
                                  "STDOUT: #{result[:stdout]}\n" \
                                  "STDERR: #{result[:stderr]}"
    end

    it 'resolves raider_reporter 0.9 from RubyGems and requires its Cucumber plugin', :aggregate_failures do
      skip 'Bundle install failed' unless bundle_install(project)

      lockfile = File.read(File.join(project, 'Gemfile.lock'))
      expect(lockfile).to match(/^    raider_reporter \(0\.9\.\d+\)$/)
      expect(File.read(File.join(project, 'features/support/env.rb'))).to include("require 'raider_reporter/cucumber'")
    end

    it 'prints pretty output and keeps the exit status of a failing Cucumber run', :aggregate_failures, :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      result = run_cucumber_with_failure(project)

      expect(result[:stdout]).to include('Feature: Reporter failure')
      expect(result[:stdout]).to include('Scenario: A deliberately failing scenario')
      expect(result[:stdout]).to match(/\d+ scenarios? \(\d+ failed/)
      expect(result[:exit_code]).to eq(1)
    end

    it 'writes raider-results/run.json listing every scenario with a failing scenario screenshot',
       :aggregate_failures, :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      result = run_cucumber_with_failure(project)
      summary = result[:stdout].match(/(\d+) scenarios? \((?:(\d+) failed)?/)
      expect(summary).not_to be_nil, "No Cucumber summary line.\nSTDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"

      run = JSON.parse(File.read(File.join(project, 'raider-results', 'run.json')))
      expect(run['schema_version']).to eq(1)
      expect(run['results'].size).to eq(summary[1].to_i)
      expect(run['results'].count { |r| r['status'] == 'failed' }).to eq(summary[2].to_i)

      failing = run['results'].find { |r| r['full_name'] == 'Reporter failure: A deliberately failing scenario' }
      expect(failing).not_to be_nil, "Scenario missing from run.json: #{run['results'].map { |r| r['full_name'] }}"
      expect(failing['status']).to eq('failed')
      expect(failing['file_path']).to eq('features/reporter_failure.feature')
      expect(failing['failure']['message']).to start_with(
        'Then the reporter records this failure (features/reporter_failure.feature:5)'
      )
      screenshot = failing['attachments'].find { |a| a['name'] == 'screenshot' }
      expect(screenshot).not_to be_nil, "No screenshot attachment: #{failing['attachments']}"
      expect(screenshot['content_type']).to eq('image/png')
    end
  end

  # Runs the project's features plus a deliberately failing scenario, then removes that scenario again
  def run_cucumber_with_failure(project)
    add_failing_cucumber_scenario(project)
    FileUtils.rm_rf(File.join(project, 'raider-results'))
    run_cucumber(project)
  ensure
    remove_failing_cucumber_scenario(project)
  end

  # Adds a scenario that always fails at its last step, after the browser has been started
  def add_failing_cucumber_scenario(project)
    File.write(File.join(project, 'features/reporter_failure.feature'), <<~FEATURE)
      Feature: Reporter failure

      Scenario: A deliberately failing scenario
          Given the reporter has a started scenario
          Then the reporter records this failure
    FEATURE
    File.write(File.join(project, 'features/step_definitions/reporter_failure_steps.rb'), <<~STEPS)
      # frozen_string_literal: true

      Given('the reporter has a started scenario') {}

      Then('the reporter records this failure') do
        raise 'deliberate failure for raider_reporter'
      end
    STEPS
  end

  # Keeps the deliberate failure from leaking into the other examples that share the project
  def remove_failing_cucumber_scenario(project)
    FileUtils.rm_f(File.join(project, 'features/reporter_failure.feature'))
    FileUtils.rm_f(File.join(project, 'features/step_definitions/reporter_failure_steps.rb'))
  end

  # Test Web Frameworks (these can run without external services)
  context 'Web Automation Frameworks' do
    describe 'Selenium + RSpec' do
      include_examples 'executable rspec project', 'rspec_selenium'
    end

    describe 'Watir + RSpec' do
      include_examples 'executable rspec project', 'rspec_watir'
    end

    describe 'Selenium + Cucumber' do
      include_examples 'executable cucumber project', 'cucumber_selenium'
    end

    describe 'Watir + Cucumber' do
      include_examples 'executable cucumber project', 'cucumber_watir'
    end
  end

  # Recorded Azure Pipelines env of a push (IndividualCI) build, see raider_reporter's CiDetector specs
  AZURE_PUSH_ENV = {
    'TF_BUILD' => 'True',
    'SYSTEM_COLLECTIONURI' => 'https://dev.azure.com/raider-test/',
    'SYSTEM_TEAMPROJECT' => 'My Project',
    'SYSTEM_TEAMPROJECTID' => '6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c',
    'BUILD_REPOSITORY_NAME' => 'web tests',
    'BUILD_REPOSITORY_ID' => '1c2bd1a0-3f63-4d93-9c3c-2b4f2b1d8f11',
    'BUILD_REPOSITORY_PROVIDER' => 'TfsGit',
    'BUILD_BUILDID' => '42',
    'SYSTEM_JOBDISPLAYNAME' => 'tests',
    'BUILD_REASON' => 'IndividualCI',
    'BUILD_SOURCEBRANCH' => 'refs/heads/release/1.2',
    'BUILD_SOURCEVERSION' => 'abc'
  }.freeze

  # Generates a ci: azure web project (the shared before(:all) only builds the default github ones)
  def generate_azure_project(framework)
    name = "azure_#{framework}_selenium"
    unless LazyProjectGenerator::GENERATED.include?(name)
      generate_framework(framework:, automation: 'selenium', name:, ci: 'azure')
      LazyProjectGenerator::GENERATED.add(name)
    end
    name
  end

  def azure_env_prefix
    "GITHUB_ACTIONS= HEADLESS=true #{AZURE_PUSH_ENV.map { |k, v| "#{k}='#{v}'" }.join(' ')}"
  end

  def expect_azure_ci_block(project)
    run = JSON.parse(File.read(File.join(project, 'raider-results', 'run.json')))
    ci = run.dig('run', 'ci') || run['ci']
    expect(ci).not_to be_nil, "No ci block in run.json: #{run.keys}"
    expect(ci['provider']).to eq('azure_pipelines')
    expect(ci['build_key']).to start_with('azure_pipelines:')
    expect(ci['build_key']).to eq(
      'azure_pipelines:dev.azure.com/raider-test/6ce954b1-ce1f-45d1-b94d-e6bf2464ba2c/' \
      '1c2bd1a0-3f63-4d93-9c3c-2b4f2b1d8f11:42:1'
    )
    expect(ci['build_url']).to eq('https://dev.azure.com/raider-test/My%20Project/_build/results?buildId=42')
    puts "\nrun.json ci block: #{JSON.pretty_generate(ci)}"
  end

  context 'Azure Pipelines projects (ci: azure)' do
    describe 'Selenium + RSpec' do
      let(:project) { generate_azure_project('rspec') }

      it 'ships azure-pipelines.yml and resolves raider_reporter 0.9', :aggregate_failures do
        expect(File).to exist(File.join(project, 'azure-pipelines.yml'))
        expect(File).not_to exist(File.join(project, '.github/workflows'))
        skip 'Bundle install failed' unless bundle_install(project)

        expect(File.read(File.join(project, 'Gemfile.lock'))).to match(/^    raider_reporter \(0\.9\.\d+\)$/)
      end

      it 'records provider azure_pipelines and an azure_pipelines: build key in run.json', :aggregate_failures, :slow do
        skip 'Bundle install failed' unless bundle_install(project)

        FileUtils.rm_rf(File.join(project, 'raider-results'))
        result = run_in_project(project, "#{azure_env_prefix} bundle exec rspec spec/ --format documentation",
                                timeout: 120)
        expect(result[:success]).to be(true), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect_azure_ci_block(project)
      end
    end

    describe 'Selenium + Cucumber' do
      let(:project) { generate_azure_project('cucumber') }

      it 'ships azure-pipelines.yml and resolves raider_reporter 0.9', :aggregate_failures do
        expect(File).to exist(File.join(project, 'azure-pipelines.yml'))
        skip 'Bundle install failed' unless bundle_install(project)

        expect(File.read(File.join(project, 'Gemfile.lock'))).to match(/^    raider_reporter \(0\.9\.\d+\)$/)
      end

      it 'records provider azure_pipelines and an azure_pipelines: build key in run.json', :aggregate_failures, :slow do
        skip 'Bundle install failed' unless bundle_install(project)

        FileUtils.rm_rf(File.join(project, 'raider-results'))
        result = run_in_project(project, "#{azure_env_prefix} bundle exec cucumber features/ --format pretty",
                                timeout: 120)
        expect(result[:success]).to be(true), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect_azure_ci_block(project)
      end
    end
  end

  # Mobile and Visual frameworks require external services, so we only verify structure
  context 'Mobile Automation Frameworks (structure validation only)' do
    describe 'iOS + RSpec' do
      it 'generates valid project structure' do
        expect(File).to exist('rspec_ios/helpers/spec_helper.rb')
        expect(File).to exist('rspec_ios/Gemfile')
        expect(File).to exist('rspec_ios/spec')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('rspec_ios', 'ruby -c helpers/spec_helper.rb')
        expect(result[:success]).to be true
      end
    end

    describe 'iOS + Cucumber' do
      it 'generates valid project structure' do
        expect(File).to exist('cucumber_ios/features/support/env.rb')
        expect(File).to exist('cucumber_ios/Gemfile')
        expect(File).to exist('cucumber_ios/features')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('cucumber_ios', 'ruby -c features/support/env.rb')
        expect(result[:success]).to be true
      end
    end

    describe 'Android + RSpec' do
      it 'generates valid project structure' do
        expect(File).to exist('rspec_android/helpers/spec_helper.rb')
        expect(File).to exist('rspec_android/Gemfile')
        expect(File).to exist('rspec_android/spec')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('rspec_android', 'ruby -c helpers/spec_helper.rb')
        expect(result[:success]).to be true
      end
    end

    describe 'Android + Cucumber' do
      it 'generates valid project structure' do
        expect(File).to exist('cucumber_android/features/support/env.rb')
        expect(File).to exist('cucumber_android/Gemfile')
        expect(File).to exist('cucumber_android/features')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('cucumber_android', 'ruby -c features/support/env.rb')
        expect(result[:success]).to be true
      end
    end

    describe 'Cross-Platform + RSpec' do
      it 'generates valid project structure' do
        expect(File).to exist('rspec_cross_platform/helpers/appium_helper.rb')
        expect(File).to exist('rspec_cross_platform/Gemfile')
        expect(File).to exist('rspec_cross_platform/spec')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('rspec_cross_platform', 'ruby -c helpers/spec_helper.rb')
        expect(result[:success]).to be true
      end
    end

    describe 'Cross-Platform + Cucumber' do
      it 'generates valid project structure' do
        expect(File).to exist('cucumber_cross_platform/helpers/appium_helper.rb')
        expect(File).to exist('cucumber_cross_platform/Gemfile')
        expect(File).to exist('cucumber_cross_platform/features')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('cucumber_cross_platform', 'ruby -c features/support/env.rb')
        expect(result[:success]).to be true
      end
    end
  end

  # Verify template system performance (caching working)
  context 'Template System Performance' do
    it 'benefits from template caching on second generation' do
      require_relative '../../lib/generators/generator'

      # Clear cache
      Generator.clear_template_cache

      # First generation (cache miss)
      start_time = Time.now
      settings1 = create_settings(framework: 'rspec', automation: 'selenium')
      settings1[:name] = 'test_cache_1'
      generate_framework(settings1)
      first_duration = Time.now - start_time

      # Second generation (cache hit)
      start_time = Time.now
      settings2 = create_settings(framework: 'rspec', automation: 'selenium')
      settings2[:name] = 'test_cache_2'
      generate_framework(settings2)
      second_duration = Time.now - start_time

      # Second generation should be faster (or similar if I/O dominates)
      # At minimum, cache should not slow things down
      expect(second_duration).to be <= (first_duration * 1.2)

      # Cleanup
      FileUtils.rm_rf('test_cache_1')
      FileUtils.rm_rf('test_cache_2')

      # Verify cache has entries
      stats = Generator.template_cache_stats
      expect(stats[:size]).to be > 0
      puts "\n📊 Template cache: #{stats[:size]} entries, ~#{stats[:memory_estimate] / 1024}KB"
    end
  end
end
