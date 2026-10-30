# frozen_string_literal: true

require_relative 'spec_helper'
require 'timeout'
require 'open3'
require 'json'
require 'erb'
require 'tmpdir'

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
  def run_in_project(project_name, command, timeout: 300, env: {})
    result = {
      success: false,
      stdout: '',
      stderr: '',
      exit_code: nil
    }

    Dir.chdir(project_name) do
      Bundler.with_unbundled_env do
        Timeout.timeout(timeout) do
          stdout, stderr, status = Open3.capture3(env, command)
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
    use_local_raider_reporter(gemfile)
  end

  # Set RAIDER_REPORTER_PATH to a raider_reporter checkout to resolve a release that is not on RubyGems yet.
  def use_local_raider_reporter(gemfile)
    path = ENV.fetch('RAIDER_REPORTER_PATH', nil)
    return unless path

    File.write(gemfile, File.read(gemfile).sub(/^gem 'raider_reporter'.*$/, "gem 'raider_reporter', path: '#{path}'"))
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

    it 'resolves raider_reporter 0.10+ from RubyGems and ships the raider-reporter executable', :aggregate_failures do
      skip 'Bundle install failed' unless bundle_install(project)

      expect(File.read(File.join(project, 'Gemfile.lock'))).to match(/^    raider_reporter \(0\.1\d\.\d+\)$/)
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

    it 'resolves raider_reporter 0.10+ from RubyGems and requires its Cucumber plugin', :aggregate_failures do
      skip 'Bundle install failed' unless bundle_install(project)

      lockfile = File.read(File.join(project, 'Gemfile.lock'))
      expect(lockfile).to match(/^    raider_reporter \(0\.1\d\.\d+\)$/)
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

    it 'writes rerun.txt listing only the failing scenario', :aggregate_failures, :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      result = run_cucumber_with_failure(project)

      expect(result[:exit_code]).to eq(1)
      rerun = File.join(project, 'rerun.txt')
      expect(File).to exist(rerun)
      expect(File.read(rerun).strip).to eq('features/reporter_failure.feature:3')
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
    FileUtils.rm_rf([File.join(project, 'raider-results'), File.join(project, 'rerun.txt')])
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
  def azure_push_env
    {
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
  end

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
    "GITHUB_ACTIONS= HEADLESS=true #{azure_push_env.map { |k, v| "#{k}='#{v}'" }.join(' ')}"
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

      it 'ships azure-pipelines.yml and resolves raider_reporter 0.10+', :aggregate_failures do
        expect(File).to exist(File.join(project, 'azure-pipelines.yml'))
        expect(File).not_to exist(File.join(project, '.github/workflows'))
        skip 'Bundle install failed' unless bundle_install(project)

        expect(File.read(File.join(project, 'Gemfile.lock'))).to match(/^    raider_reporter \(0\.1\d\.\d+\)$/)
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

      it 'ships azure-pipelines.yml and resolves raider_reporter 0.10+', :aggregate_failures do
        expect(File).to exist(File.join(project, 'azure-pipelines.yml'))
        skip 'Bundle install failed' unless bundle_install(project)

        expect(File.read(File.join(project, 'Gemfile.lock'))).to match(/^    raider_reporter \(0\.1\d\.\d+\)$/)
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

  # Failure video replay against real browsers. Needs an ffmpeg with libvpx (RAIDER_FFMPEG_PATH), because the
  # RaiderHQ ffmpeg release has no checksums yet. Skipped when it, or the browser, is missing. Firefox can be
  # pointed at a specific binary with FIREFOX_BINARY.
  context 'Failure video replay', :slow, :video do
    let(:ffmpeg_path) { ENV.fetch('RAIDER_FFMPEG_PATH', '') }
    let(:cache_dir) { Dir.mktmpdir('raider-cache') }

    after { FileUtils.rm_rf(cache_dir) }

    def skip_unless_video_prerequisites(browser)
      skip 'RAIDER_FFMPEG_PATH is not set to an executable ffmpeg with libvpx' unless
        File.file?(ffmpeg_path) && File.executable?(ffmpeg_path)
      skip "#{browser} is not installed" unless browser_installed?(browser)
    end

    def browser_installed?(browser)
      if browser == 'firefox'
        ENV['FIREFOX_BINARY'] ? File.executable?(ENV['FIREFOX_BINARY']) : app_or_command?('Firefox', 'firefox')
      else
        app_or_command?('Google Chrome', 'google-chrome') || app_or_command?('Chromium', 'chromium')
      end
    end

    def app_or_command?(app, command)
      File.directory?("/Applications/#{app}.app") || system("command -v #{command} > /dev/null 2>&1")
    end

    # A separate project, so the default projects keep resolving raider_reporter 0.10+ from RubyGems
    def generate_video_project(framework, automation)
      name = "video_#{framework}_#{automation}"
      unless LazyProjectGenerator::GENERATED.include?(name)
        generate_framework(framework:, automation:, name:)
        LazyProjectGenerator::GENERATED.add(name)
        use_local_ruby_raider(name)
        expect(run_in_project(name, 'bundle install --quiet', timeout: 300)[:success]).to be(true)
      end
      FileUtils.rm_rf(File.join(name, 'raider-results'))
      name
    end

    def video_env(overrides = {})
      { 'HEADLESS' => 'true', 'RAIDER_FFMPEG_PATH' => ffmpeg_path, 'RAIDER_CACHE_DIR' => cache_dir,
        'RAIDER_TOKEN' => nil, 'RAIDER_ENDPOINT' => nil, 'VIDEO' => nil }.merge(overrides)
    end

    def page_url
      "data:text/html,#{ERB::Util.url_encode('<h1 id="title">Video</h1><input id="name"><button id="go">Go</button>')}"
    end

    def add_rspec_video_spec(project)
      File.write(File.join(project, 'spec/video_replay_spec.rb'), <<~SPEC)
        # frozen_string_literal: true

        require_relative '../helpers/spec_helper'

        describe 'Video replay' do
          it 'passes after driving the page' do
            driver.navigate.to('#{page_url}')
            driver.find_element(id: 'name').send_keys('ok')
            expect(driver.find_element(id: 'title').text).to eq('Video')
          end

          it 'fails after driving the page' do
            driver.navigate.to('#{page_url}')
            driver.find_element(id: 'name').send_keys('broken')
            driver.find_element(id: 'go').click
            expect(driver.find_element(id: 'title').text).to eq('deliberate video failure')
          end
        end
      SPEC
    end

    def add_cucumber_video_feature(project, firefox_binary)
      File.write(File.join(project, 'features/video_replay.feature'), <<~FEATURE)
        Feature: Video replay

        Scenario: A passing scenario
            Given the video page is open
            Then the video page title is "Video"

        Scenario: A failing scenario
            Given the video page is open
            Then the video page title is "deliberate video failure"
      FEATURE
      File.write(File.join(project, 'features/step_definitions/video_replay_steps.rb'), <<~STEPS)
        # frozen_string_literal: true

        Given('the video page is open') do
          browser.goto('#{page_url}')
          browser.text_field(id: 'name').set('typed')
          browser.button(id: 'go').click
        end

        Then('the video page title is {string}') do |title|
          raise "expected title \#{title}" unless browser.h1(id: 'title').text == title
        end
      STEPS
      config = File.join(project, 'config/config.yml')
      File.write(config, File.read(config).sub(/^browser: .*$/, 'browser: firefox'))
      # Test setup only: the generated templates do not read FIREFOX_BINARY.
      File.write(File.join(project, 'features/support/zz_firefox_binary.rb'), <<~RUBY) if firefox_binary
        # frozen_string_literal: true

        Selenium::WebDriver::Firefox.path = ENV['FIREFOX_BINARY'] if ENV['FIREFOX_BINARY']
      RUBY
    end

    def results(project)
      JSON.parse(File.read(File.join(project, 'raider-results', 'run.json')))['results']
    end

    def video_files(project)
      Dir.glob(File.join(project, 'raider-results', '**', '*.{webm,mp4}'))
    end

    def video_attachments(result)
      result['attachments'].select { |attachment| attachment['name'] == 'video' }
    end

    def expect_video_for_failure_only(project, failing_name, run)
      by_status = results(project).group_by { |r| r['status'] }
      expect(by_status.keys).to match_array(%w[passed failed]), "STDOUT: #{run[:stdout]}\nSTDERR: #{run[:stderr]}"
      failing = by_status['failed'].find { |r| r['full_name'].include?(failing_name) }
      expect(failing).not_to be_nil, "No failing result named #{failing_name}"
      expect(video_attachments(failing).size).to eq(1)
      expect(video_attachments(failing).first['content_type']).to eq('video/webm')
      by_status.fetch('passed', []).each { |r| expect(video_attachments(r)).to be_empty }
      videos = video_files(project)
      expect(videos.size).to eq(1)
      expect(videos.first).to end_with('video.webm')
      expect(File.size(videos.first)).to be_positive
      expect(File.read(File.join(project, 'raider-results', 'index.html'))).to include('<video')
    end

    describe 'Selenium + RSpec on headless Chrome' do
      let(:project) { 'video_rspec_selenium' }
      let(:command) { 'bundle exec rspec spec/video_replay_spec.rb' }

      before do
        skip_unless_video_prerequisites('chrome')
        generate_video_project('rspec', 'selenium')
        add_rspec_video_spec(project)
      end

      after { FileUtils.rm_f(File.join(project, 'spec/video_replay_spec.rb')) }

      it 'attaches video.webm to the failing example only and plays it in index.html', :aggregate_failures do
        result = run_in_project(project, command, env: video_env)
        expect(result[:exit_code]).to eq(1), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect(result[:stderr]).not_to include('[video]')
        expect_video_for_failure_only(project, 'fails after driving the page', result)
      end

      it 'writes no video with VIDEO=off', :aggregate_failures do
        result = run_in_project(project, command, env: video_env('VIDEO' => 'off'))
        expect(result[:exit_code]).to eq(1), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect(video_files(project)).to be_empty
        expect(results(project).flat_map { |r| video_attachments(r) }).to be_empty
        expect(result[:stderr]).not_to include('[video]')
      end

      it 'runs unchanged with one [video] line and no download when no ffmpeg is usable', :aggregate_failures do
        off = run_in_project(project, command, env: video_env('VIDEO' => 'off'))
        FileUtils.rm_rf(File.join(project, 'raider-results'))
        result = run_in_project(project, command, env: video_env('RAIDER_FFMPEG_PATH' => nil))

        expect(result[:exit_code]).to eq(off[:exit_code]), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        video_lines = result[:stderr].lines.grep(/\[video\]/)
        expect(video_lines.size).to eq(1), "STDERR: #{result[:stderr]}"
        # Decided at the first driver/recorder call, before any capture or fetch: the placeholder
        # manifest has no checksum, so nothing is captured or downloaded.
        expect(video_lines.first).to include('no ffmpeg available for this platform yet')
        expect(video_files(project)).to be_empty
        expect(Dir.glob(File.join(cache_dir, '**', '*'))).to be_empty
      end
    end

    describe 'Watir + Cucumber on headless Firefox' do
      let(:project) { 'video_cucumber_watir' }
      let(:firefox_binary) { ENV.fetch('FIREFOX_BINARY', nil) }

      before do
        skip_unless_video_prerequisites('firefox')
        generate_video_project('cucumber', 'watir')
        add_cucumber_video_feature(project, firefox_binary)
      end

      after do
        FileUtils.rm_f(File.join(project, 'features/video_replay.feature'))
        FileUtils.rm_f(File.join(project, 'features/step_definitions/video_replay_steps.rb'))
      end

      it 'attaches video.webm to the failing scenario only and plays it in index.html', :aggregate_failures do
        result = run_in_project(project, 'bundle exec cucumber features/video_replay.feature',
                                env: video_env('FIREFOX_BINARY' => firefox_binary), timeout: 240)
        expect(result[:exit_code]).to eq(1), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect(result[:stderr]).not_to include('[video]')
        expect_video_for_failure_only(project, 'A failing scenario', result)
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
