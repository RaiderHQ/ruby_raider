# frozen_string_literal: true

require_relative 'spec_helper'
require 'timeout'
require 'open3'
require 'json'
require 'erb'
require 'tmpdir'
require_relative 'trace_format_checker'
require_relative 'trace_page_server'

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

  # Runs the project's own RuboCop with the gems its bundle resolved (newer than this gem's dev bundle).
  # It runs from a copy outside this repo, as a user's project would: inside it RuboCop would also read
  # this repo's .rubocop.yml, gemspec and .ruby-version.
  def expect_project_rubocop_clean(project)
    skip 'Bundle install failed' unless bundle_install(project)

    Dir.mktmpdir('raider_rubocop') do |tmp|
      copy = File.join(tmp, project)
      FileUtils.cp_r(project, copy)
      puts run_in_project(copy, 'bundle exec rubocop -V', timeout: 60)[:stdout]
      result = run_in_project(copy, 'bundle exec rubocop --cache false', timeout: 180)
      expect(result[:exit_code]).to eq(0), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
    end
  end

  # Test Web Frameworks (these can run without external services)
  context 'Web Automation Frameworks' do
    describe 'Selenium + RSpec' do
      include_examples 'executable rspec project', 'rspec_selenium'

      it 'passes its own RuboCop with its bundled gems', :slow do
        expect_project_rubocop_clean('rspec_selenium')
      end

      it 'saves the login once and reuses it', :aggregate_failures, :slow do
        skip 'Bundle install failed' unless bundle_install('rspec_selenium')

        state_file = File.join('rspec_selenium', '.raider', 'auth', 'user.json')
        FileUtils.rm_rf(File.join('rspec_selenium', '.raider'))
        first = run_in_project('rspec_selenium', 'bundle exec rspec spec/', env: { 'HEADLESS' => 'true' })
        failed = ->(run, index) { "Run #{index} failed.\nSTDOUT: #{run[:stdout]}\nSTDERR: #{run[:stderr]}" }
        raise failed.call(first, 1) unless first[:exit_code].zero? # show run 1's output, not a missing state file

        expect(File).to exist(state_file)
        saved = JSON.parse(File.read(state_file))
        second = run_in_project('rspec_selenium', 'bundle exec rspec spec/', env: { 'HEADLESS' => 'true' })
        expect(second[:exit_code]).to eq(0), failed.call(second, 2)
        expect(File.stat(state_file).mode & 0o777).to eq(0o600)
        expect(saved).to include('format' => 1, 'origin' => 'https://raider-test-site.onrender.com')
        expect(JSON.parse(File.read(state_file))['saved_at']).to eq(saved['saved_at'])
        cookie_values = saved['cookies'].map { |cookie| cookie['value'].to_s }
        expect(cookie_values.reject(&:empty?)).not_to be_empty
        output = [first, second].map { |run| run[:stdout] + run[:stderr] }.join
        # Short values like "1" or "en" can appear in any output; a leaked token is long.
        cookie_values.select { |value| value.length >= 8 }.each { |value| expect(output).not_to include(value) }
      end
    end

    describe 'Watir + RSpec' do
      include_examples 'executable rspec project', 'rspec_watir'
    end

    describe 'Selenium + Cucumber' do
      include_examples 'executable cucumber project', 'cucumber_selenium'

      it 'passes its own RuboCop with its bundled gems', :slow do
        expect_project_rubocop_clean('cucumber_selenium')
      end
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

  # An empty skeleton (examples: false) still passes its run, so its CI is green until tests are added
  def generate_skeleton_project(framework)
    name = "skeleton_e2e_#{framework}_selenium"
    unless LazyProjectGenerator::GENERATED.include?(name)
      generate_framework(framework:, automation: 'selenium', name:, examples: false)
      LazyProjectGenerator::GENERATED.add(name)
    end
    name
  end

  context 'Empty skeleton projects (examples: false)' do
    it 'runs bundle exec rspec on a selenium rspec skeleton with 0 examples', :aggregate_failures do
      project = generate_skeleton_project('rspec')
      skip 'Bundle install failed' unless bundle_install(project)

      ['rspec', 'rspec spec/'].each do |command|
        result = run_in_project(project, "bundle exec #{command}", timeout: 120)
        expect(result[:exit_code]).to eq(0), "#{command}\nSTDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect(result[:stdout]).to include('0 examples, 0 failures')
      end
    end

    it 'runs bundle exec cucumber on a selenium cucumber skeleton with 0 scenarios', :aggregate_failures do
      project = generate_skeleton_project('cucumber')
      skip 'Bundle install failed' unless bundle_install(project)

      ['cucumber', 'cucumber features'].each do |command|
        result = run_in_project(project, "bundle exec #{command}", timeout: 120)
        expect(result[:exit_code]).to eq(0), "#{command}\nSTDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
        expect(result[:stdout]).to include('0 scenarios')
      end
    end
  end

  # Browser e2e helpers shared by the failure video and the trace replay contexts
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

  def results(project)
    JSON.parse(File.read(File.join(project, 'raider-results', 'run.json')))['results']
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

  # Trace replay against headless Chrome, and one example on headless Firefox. The page is served over HTTP from this process (never file://), so
  # WebDriver BiDi reports real network and console entries. raider_reporter ~> 0.12 resolves from RubyGems, or
  # from a checkout at RAIDER_REPORTER_PATH. The example with video on also needs RAIDER_FFMPEG_PATH.
  # Set TRACE_FIXTURE_DIR to keep the failing RSpec example's trace.zip (and an unzipped copy) there.
  context 'Trace replay', :slow do
    let!(:server) { TracePageServer.new }
    let(:cache_dir) { Dir.mktmpdir('raider-cache') }

    after do
      server.stop
      FileUtils.rm_rf(cache_dir)
    end

    # Typed into the secret fields; neither may reach the zip.
    def secrets
      %w[hunter2 s3cr3t]
    end

    # Typed into a plain field; it is kept as the step's value.
    def plain_value
      'plain-trace-name'
    end

    def skip_unless_trace_prerequisites(project, browser = 'chrome')
      skip "#{browser == 'chrome' ? 'Google Chrome' : 'Firefox'} is not installed" unless browser_installed?(browser)
      version = run_in_project(project, %(bundle exec ruby -e "require 'raider_reporter/version'; print RaiderReporter::VERSION"))
      skip "the bundle does not resolve raider_reporter ~> 0.12 (set RAIDER_REPORTER_PATH): #{version[:stderr].lines.last}" unless
        version[:success] && Gem::Version.new(version[:stdout]) >= Gem::Version.new('0.12')
    end

    def trace_env(overrides = {})
      { 'HEADLESS' => 'true', 'VIDEO' => 'off', 'TRACE' => nil, 'RAIDER_CACHE_DIR' => cache_dir,
        'RAIDER_TOKEN' => nil, 'RAIDER_ENDPOINT' => nil }.merge(overrides)
    end

    def trace_attachments(result)
      result['attachments'].select { |attachment| attachment['name'] == 'trace' }
    end

    def trace_files(project)
      Dir.glob(File.join(project, 'raider-results', '**', '*trace.zip'))
    end

    def trace_zip(project, attachment)
      File.join(project, 'raider-results', attachment['path'])
    end

    # { entry name => bytes } for every entry of the zip.
    def zip_entries(path)
      Zip::File.open(path) { |zip| zip.entries.to_h { |entry| [entry.name, entry.get_input_stream.read] } }
    end

    def result_named(project, name)
      results(project).find { |result| result['full_name'].include?(name) }
    end

    def expect_run(result, exit_code: 1)
      expect(result[:exit_code]).to eq(exit_code), "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
      expect(result[:stderr]).not_to include('[trace]')
    end

    def expect_valid_trace(path)
      expect(TraceFormatChecker.problems(path)).to be_empty
    end

    def keep_fixture(path)
      dir = ENV.fetch('TRACE_FIXTURE_DIR', nil)
      return unless dir

      FileUtils.rm_rf(File.join(dir, 'unzipped'))
      FileUtils.mkdir_p(File.join(dir, 'unzipped'))
      FileUtils.cp(path, File.join(dir, 'trace.zip'))
      zip_entries(path).each do |name, bytes|
        FileUtils.mkdir_p(File.dirname(File.join(dir, 'unzipped', name)))
        File.binwrite(File.join(dir, 'unzipped', name), bytes)
      end
    end

    # The RSpec examples' names, spec file and readers, shared by the Chrome and Firefox examples.
    def failing
      'fails after driving the page'
    end

    def passing
      'passes after driving the page'
    end

    # Drives the page through the generated WaitHelper, so the trace has action steps.
    # Each example prints the driver's webSocketUrl, which is set only while tracing is on.
    def add_rspec_trace_spec(project)
      File.write(File.join(project, 'spec/trace_replay_spec.rb'), <<~SPEC)
        # frozen_string_literal: true

        require_relative '../helpers/spec_helper'

        describe 'Trace replay' do
          it '#{failing}' do
            driver.navigate.to('#{server.url}start')
            puts "TRACE_E2E_WEBSOCKET=\#{driver.capabilities[:web_socket_url].inspect}"
            send_keys({ id: 'pw' }, '#{secrets[0]}')
            send_keys({ id: 'pw2' }, '#{secrets[1]}')
            find_element(id: 'name').send_keys('#{plain_value}')
            click({ id: 'go' })
            eventually(timeout: 5) { expect(text(id: 'status')).to eq('answered by /api') }
            eventually(timeout: 1) { expect(text(id: 'title')).to eq('deliberate trace failure') }
          end

          it '#{passing}' do
            driver.navigate.to('#{server.url}')
            puts "TRACE_E2E_WEBSOCKET=\#{driver.capabilities[:web_socket_url].inspect}"
            send_keys({ id: 'name' }, 'ok')
            eventually { expect(text(id: 'title')).to eq('Trace') }
          end
        end
      SPEC
    end

    def failing_trace(result)
      expect(trace_attachments(result).size).to eq(1)
      trace_zip(project, trace_attachments(result).first)
    end

    def steps_of(path)
      TraceFormatChecker.read(path).first['steps']
    end

    # BiDi screenshots, so window_handle worked as the browsing context id: .jpg entries that are JPEGs.
    def expect_jpeg_screenshots(path, names)
      screenshots = names.grep(%r{\Asteps/\d{4}\.(jpg|png)\z})
      expect(screenshots).not_to be_empty
      expect(screenshots).to all(end_with('.jpg'))
      entries = zip_entries(path)
      screenshots.each { |name| expect(entries[name].byteslice(0, 2).bytes).to eq([0xFF, 0xD8]), name }
    end

    describe 'Selenium + RSpec on headless Chrome' do
      let(:project) { 'video_rspec_selenium' }
      let(:command) { 'bundle exec rspec spec/trace_replay_spec.rb' }

      before do
        generate_video_project('rspec', 'selenium')
        skip_unless_trace_prerequisites(project)
        add_rspec_trace_spec(project)
      end

      after { FileUtils.rm_f(File.join(project, 'spec/trace_replay_spec.rb')) }

      # A navigate step (Selenium sends get through BiDi with web_socket_url set), and action steps whose
      # elements have a label and a rect.
      def expect_steps(steps)
        expect(steps.map { |step| step['kind'] }).to include('navigate')
        actions = steps.select { |step| %w[click send_keys].include?(step['action']) }
        expect(actions.size).to eq(4)
        expect(actions).to all(include('element' => include('label' => a_kind_of(String)), 'rect' => a_kind_of(Hash)))
      end

      def expect_network_and_console(trace)
        api = trace['network'].find { |entry| entry['url'].to_s.end_with?('/api') }
        expect(api).to include('method' => 'GET', 'status' => 200, 'mime_type' => 'application/json')
        expect(api['bytes']).to be_positive
        expect(api['duration_ms']).to be >= (TracePageServer::API_DELAY * 1000) - 50
        expect(trace['console']).to include(include('level' => 'error', 'text' => a_string_including('trace e2e error')))
      end

      # /start redirects to /: two entries, one per hop, both credited to the navigate step.
      def expect_redirect_hops(trace)
        navigate = trace['steps'].find { |step| step['kind'] == 'navigate' }
        start = trace['network'].find { |entry| entry['url'].to_s.end_with?('/start') }
        page = trace['network'].find { |entry| entry['url'] == server.url }
        expect(start).to include('status' => 302, 'step_index' => navigate['index'])
        expect(page).to include('status' => 200, 'step_index' => navigate['index'])
        expect(page['duration_ms']).to be >= (TracePageServer::PAGE_DELAY * 1000) - 50
      end

      # The same-origin stylesheet inlined as <style>, and the page's <script> gone.
      def expect_sanitised_snapshots(path, names)
        entries = zip_entries(path)
        snapshots = names.grep(%r{\Asteps/\d{4}\.html\z}).map { |name| entries[name] }
        expect(snapshots).not_to be_empty
        expect(snapshots).to all(match(/<style[^>]*>[^<]*#{Regexp.escape(TracePageServer::CSS_RULE)}/))
        expect(snapshots).to all(satisfy { |html| !html.match?(/<script/i) })
      end

      it 'attaches one trace.zip to the failing example only, valid against raider-trace v1, with network and console',
         :aggregate_failures do
        run = run_in_project(project, command, env: trace_env)
        expect_run(run)
        failed = result_named(project, failing)
        attachment = trace_attachments(failed).first
        path = failing_trace(failed)
        keep_fixture(path)

        expect(run[:stdout]).to include('TRACE_E2E_WEBSOCKET="ws://')
        expect(attachment).to include('content_type' => 'application/vnd.raider.trace+zip', 'attempt' => 1)
        expect(trace_attachments(result_named(project, passing))).to be_empty
        expect(trace_files(project).size).to eq(1)
        expect_valid_trace(path)

        trace, names = TraceFormatChecker.read(path)
        expect(trace['capabilities']).to include('network' => true, 'console' => true)
        expect_steps(trace['steps'])
        expect_jpeg_screenshots(path, names)
        expect_network_and_console(trace)
        expect_redirect_hops(trace)
        expect_sanitised_snapshots(path, names)
      end

      it 'masks the typed password', :aggregate_failures do
        run = run_in_project(project, command, env: trace_env)
        expect_run(run)
        path = failing_trace(result_named(project, failing))

        zip_entries(path).each do |name, bytes|
          secrets.each { |secret| expect(bytes.b).not_to include(secret.b), "#{secret} is in #{name}" }
        end
        typed = steps_of(path).select { |step| step['action'] == 'send_keys' }
        expect(typed.size).to eq(3)
        expect(typed.first(2)).to all(include('value' => nil, 'secret' => true))
        expect(typed.last).to include('value' => plain_value, 'secret' => false)
      end

      it 'writes no trace and no web_socket_url with TRACE=off', :aggregate_failures do
        run = run_in_project(project, command, env: trace_env('TRACE' => 'off'))
        expect_run(run)
        expect(run[:stdout].scan(/^TRACE_E2E_WEBSOCKET=(.*)$/).flatten).to eq(%w[nil nil])
        expect(results(project).flat_map { |result| trace_attachments(result) }).to be_empty
        expect(trace_files(project)).to be_empty
      end

      it 'keeps traces for passing examples too with TRACE=on', :aggregate_failures do
        run = run_in_project(project, command, env: trace_env('TRACE' => 'on'))
        expect_run(run)
        [failing, passing].each do |name|
          attachments = trace_attachments(result_named(project, name))
          expect(attachments.size).to eq(1), "#{name} has #{attachments.size} traces"
          expect_valid_trace(trace_zip(project, attachments.first)) if attachments.one?
        end
        expect(trace_files(project).size).to eq(2)
      end

      # Spec §2 Cost: tracing on failing tests (the default) costs under 15% of the wall-clock time.
      # One warm-up run, then the modes interleaved, three runs each, compared by their medians.
      # Opt-in: CI runs the integration specs on every PR, and runner jitter is the size of the margin.
      it 'keeps the suite within 15% of its TRACE=off wall-clock time' do
        skip 'set TRACE_OVERHEAD=1 to measure trace overhead' unless ENV['TRACE_OVERHEAD']

        run_in_project(project, command, env: trace_env)
        times = Hash.new { |hash, key| hash[key] = [] }
        3.times do
          { 'off' => 'off', 'default' => nil }.each do |mode, value|
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            expect_run(run_in_project(project, command, env: trace_env('TRACE' => value)))
            times[mode] << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
          end
        end
        off, traced = times.values_at('off', 'default').map { |runs| runs.sort[1] }
        overhead = (traced - off) / off
        puts format("\n[trace overhead] TRACE=off %<off>s, default %<default>s, medians %<o>.2fs vs %<t>.2fs: %<p>+.1f%%",
                    off: times['off'].map { |time| time.round(2) }, default: times['default'].map { |time| time.round(2) },
                    o: off, t: traced, p: overhead * 100)
        expect(overhead).to be < 0.15
      end

      it 'attaches video.webm and trace.zip to the failing example with video on', :aggregate_failures do
        ffmpeg = ENV.fetch('RAIDER_FFMPEG_PATH', '')
        skip 'RAIDER_FFMPEG_PATH is not set to an executable ffmpeg with libvpx' unless
          File.file?(ffmpeg) && File.executable?(ffmpeg)

        run = run_in_project(project, command, env: trace_env('VIDEO' => nil, 'RAIDER_FFMPEG_PATH' => ffmpeg))
        expect_run(run)
        expect(run[:stderr]).not_to include('[video]')
        attachments = result_named(project, failing)['attachments']
        expect(attachments.map { |attachment| attachment['content_type'] })
          .to include('video/webm', 'application/vnd.raider.trace+zip')
        expect(attachments.map { |attachment| File.basename(attachment['path']) })
          .to include(a_string_ending_with('video.webm'), a_string_ending_with('trace.zip'))
        expect_valid_trace(failing_trace(result_named(project, failing)))
      end
    end

    # The same RSpec project with config.yml set to firefox; Selenium Manager fetches geckodriver.
    describe 'Selenium + RSpec on headless Firefox' do
      let(:project) { 'video_rspec_selenium' }
      let(:config) { File.join(project, 'config/config.yml') }
      # Read before the switch to firefox and written back after, so the Chrome examples keep chrome.
      let(:original_config) { File.read(config) }

      before do
        generate_video_project('rspec', 'selenium')
        skip_unless_trace_prerequisites(project, 'firefox')
        File.write(config, original_config.sub(/^browser: .*$/, 'browser: firefox'))
        add_rspec_trace_spec(project)
      end

      after do
        File.write(config, original_config) if File.exist?(config)
        FileUtils.rm_f(File.join(project, 'spec/trace_replay_spec.rb'))
      end

      it 'attaches a trace.zip valid against raider-trace v1, with network, console and BiDi JPEG screenshots',
         :aggregate_failures do
        run = run_in_project(project, 'bundle exec rspec spec/trace_replay_spec.rb', env: trace_env, timeout: 240)
        expect_run(run)
        path = failing_trace(result_named(project, failing))
        expect_valid_trace(path)

        trace, names = TraceFormatChecker.read(path)
        expect(trace['browser']).to include('name' => 'firefox')
        expect(trace['capabilities']).to include('network' => true, 'console' => true)
        expect_jpeg_screenshots(path, names)
        api = trace['network'].find { |entry| entry['url'].to_s.end_with?('/api') }
        expect(api).to include('status' => 200)
        expect(api && api['duration_ms']).to be_a(Integer).and be_positive
      end
    end

    describe 'Selenium + Cucumber on headless Chrome' do
      let(:project) { 'video_cucumber_selenium' }

      before do
        generate_video_project('cucumber', 'selenium')
        skip_unless_trace_prerequisites(project)
        add_cucumber_trace_feature(project)
      end

      after do
        FileUtils.rm_f(File.join(project, 'features/trace_replay.feature'))
        FileUtils.rm_f(File.join(project, 'features/step_definitions/trace_replay_steps.rb'))
      end

      def add_cucumber_trace_feature(project)
        File.write(File.join(project, 'features/trace_replay.feature'), <<~FEATURE)
          Feature: Trace replay

          Scenario: A failing traced scenario
              Given the trace page is open
              When I type a name on the trace page
              Then the trace page title is "deliberate trace failure"
        FEATURE
        File.write(File.join(project, 'features/step_definitions/trace_replay_steps.rb'), <<~STEPS)
          # frozen_string_literal: true

          Given('the trace page is open') do
            driver.navigate.to('#{server.url}')
          end

          When('I type a name on the trace page') do
            send_keys({ id: 'name' }, '#{plain_value}')
            click({ id: 'go' })
          end

          Then('the trace page title is {string}') do |title|
            eventually(timeout: 1) { expect(text(id: 'title')).to eq(title) }
          end
        STEPS
      end

      it 'attaches a trace.zip with Gherkin step groups to the failing scenario', :aggregate_failures do
        run = run_in_project(project, 'bundle exec cucumber features/trace_replay.feature', env: trace_env, timeout: 240)
        expect_run(run)
        attachments = trace_attachments(result_named(project, 'A failing traced scenario'))
        expect(attachments.size).to eq(1)
        expect(attachments.first).to include('content_type' => 'application/vnd.raider.trace+zip', 'attempt' => 1)
        path = trace_zip(project, attachments.first)
        expect_valid_trace(path)
        groups = TraceFormatChecker.read(path).first['steps'].select { |step| step['action'] == 'cucumber_step' }
        expect(groups).to include(include('kind' => 'group', 'name' => a_string_including('the trace page is open')))
      end
    end

    # mock_request / block_request through WebDriver BiDi, on a page that fetches /api/* and a cross-origin URL
    # that exists nowhere (so it only answers when mocked). Chrome by default; Edge and Firefox run only when
    # RAIDER_E2E_BROWSERS (comma separated) lists them.
    describe 'Network mocking' do
      let(:project) { 'video_rspec_selenium' }
      let(:original_config) { File.read(config) }

      def config
        File.join(project, 'config/config.yml')
      end

      def spec_path
        File.join(project, 'spec/network_mocking_spec.rb')
      end

      def opted_in?(browser)
        ENV.fetch('RAIDER_E2E_BROWSERS', '').split(',').map(&:strip).include?(browser)
      end

      def skip_unless_mocking_prerequisites(browser)
        skip "set RAIDER_E2E_BROWSERS=#{browser} to run network mocking on #{browser}" unless browser == 'chrome' || opted_in?(browser)
        skip 'Microsoft Edge is not installed' if browser == 'edge' && !File.directory?('/Applications/Microsoft Edge.app')
        skip_unless_trace_prerequisites(project, browser == 'firefox' ? 'firefox' : 'chrome')
      end

      def write_spec(body)
        File.write(spec_path, <<~SPEC)
          # frozen_string_literal: true

          require_relative '../helpers/spec_helper'

          describe 'Network mocking' do
          #{body.lines.map { |line| line.strip.empty? ? line : "  #{line}" }.join}
          end
        SPEC
      end

      def mocking_run(overrides = {})
        run_in_project(project, 'bundle exec rspec spec/network_mocking_spec.rb', env: trace_env(overrides), timeout: 240)
      end

      def mock_example(browser)
        write_spec(<<~BODY)
          it 'mocks, blocks, edits and removes' do
            driver.navigate.to('#{server.url}mock')
            users = mock_request('#{server.url}api/users', json: { users: ['ana'] })
            block_request('**/api/fail')
            mock_request('**/api/echo') { { continue: { headers: { 'x-raider' => 'yes' } } } }
            mock_request('http://mock.raider.test/api/cors', json: { ok: true })
            click({ id: 'users' })
            eventually(timeout: 5) { expect(text(id: 'users-out')).to eq('ana') }
            click({ id: 'fail' })
            eventually(timeout: 5) { expect(text(id: 'fail-out')).to eq('request failed') }
            click({ id: 'echo' })
            eventually(timeout: 5) { expect(text(id: 'echo-out')).to eq('echo yes') }
            click({ id: 'cors' })
            eventually(timeout: 5) { expect(text(id: 'cors-out')).to eq('cors true') }
            expect(users.calls.size).to eq(1)
            expect(users).to be_called
            remove_mock(users)
            click({ id: 'users' })
            eventually(timeout: 5) { expect(text(id: 'users-out')).to eq('real') }
            expect(users.calls.size).to eq(1)
            puts 'NETWORK_MOCKING_#{browser.upcase}_DONE'
          end
        BODY
      end

      def switch_browser(name)
        # The generated config carries browser arguments for chrome and firefox only.
        edge_args = "  edge:\n    - no-sandbox\n"
        File.write(config, original_config.sub(/^browser: .*$/, "browser: #{name}").sub(/^  firefox:/, "#{edge_args}  firefox:"))
      end

      # Skips when the browser is unavailable or not opted in; otherwise points the config at it.
      def use_browser(name)
        skip_unless_mocking_prerequisites(name)
        original_config
        switch_browser(name)
      end

      before { generate_video_project('rspec', 'selenium') }

      after do
        File.write(config, original_config) if File.exist?(config)
        FileUtils.rm_f(spec_path)
      end

      %w[chrome edge firefox].each do |name|
        it "mocks, blocks, edits headers and removes a mock on headless #{name}", :aggregate_failures do
          use_browser(name)
          mock_example(name)
          run = mocking_run('TRACE' => 'off')
          expect_run(run, exit_code: 0)
          expect(run[:stdout]).to include("NETWORK_MOCKING_#{name.upcase}_DONE")
        end
      end

      def write_failing_spec
        write_spec(<<~BODY)
          it 'fails after mocking' do
            driver.navigate.to('#{server.url}mock')
            mock_request('#{server.url}api/users', json: { users: ['ana'] })
            block_request('#{server.url}api/fail')
            click({ id: 'users' })
            eventually(timeout: 5) { expect(text(id: 'users-out')).to eq('ana') }
            click({ id: 'fail' })
            eventually(timeout: 5) { expect(text(id: 'fail-out')).to eq('request failed') }
            eventually(timeout: 1) { expect(text(id: 'users-out')).to eq('deliberate mocking failure') }
          end
        BODY
      end

      it 'keeps mocked entries in the failing example trace', :aggregate_failures do
        use_browser('chrome')
        write_failing_spec
        expect_run(mocking_run)
        path = failing_trace(result_named(project, 'fails after mocking'))
        keep_fixture(path)
        expect_valid_trace(path)
        network = TraceFormatChecker.read(path).first['network']
        users = network.find { |entry| entry['url'].to_s.end_with?('/api/users') }
        failed = network.find { |entry| entry['url'].to_s.end_with?('/api/fail') }
        expect(users).to include('mocked' => 'fulfilled', 'status' => 200)
        expect(failed).to include('mocked' => 'failed')
      end

      it 'fails the example with MockError when a block raises', :aggregate_failures do
        use_browser('chrome')
        write_spec(<<~BODY)
          it 'has a raising block' do
            driver.navigate.to('#{server.url}mock')
            mock_request('#{server.url}api/users') { raise 'boom from the block' }
            click({ id: 'users' })
            eventually(timeout: 5) { expect(text(id: 'users-out')).to eq('users failed') }
          end
        BODY
        run = mocking_run('TRACE' => 'off')
        expect(run[:exit_code]).to eq(1), "STDOUT: #{run[:stdout]}\nSTDERR: #{run[:stderr]}"
        expect(run[:stdout]).to include('NetworkHelper::MockError', 'boom from the block')
      end
    end
  end

  # match_screenshot against real browsers, on a fixed data: page (no server, no animation). Chrome by default; Edge and
  # Firefox run only when RAIDER_E2E_BROWSERS (comma separated) lists them. The generated spec or step recolours the page
  # when SHOT_VARIANT=changed. raider_reporter comes from RubyGems (no `comparison` method yet), so the images are
  # attached and one warning is printed; the report's comparisons field is not asserted here.
  context 'Screenshot comparison', :slow do
    let(:cache_dir) { Dir.mktmpdir('raider-cache') }
    let(:baseline) { "screenshots/baselines/#{browser_name}/home.png" }
    let(:original_config) { File.read(config_path) }

    after do
      File.write(config_path, original_config) if File.exist?(config_path)
      FileUtils.rm_rf(File.join(project, 'screenshots'))
      FileUtils.rm_f(File.join(project, 'spec/screenshot_comparison_spec.rb'))
      FileUtils.rm_f(File.join(project, 'features/screenshot_comparison.feature'))
      FileUtils.rm_f(File.join(project, 'features/step_definitions/screenshot_comparison_steps.rb'))
      FileUtils.rm_rf(cache_dir)
    end

    def config_path
      File.join(project, 'config/config.yml')
    end

    def shot_page
      html = '<body style="margin:0;font-family:monospace"><h1 id="title">Screenshot</h1><p>Fixed content</p></body>'
      "data:text/html,#{ERB::Util.url_encode(html)}"
    end

    def recolour
      "document.documentElement.style.background = 'rgb(200, 0, 0)'; document.body.style.background = 'rgb(200, 0, 0)'"
    end

    def shot_env(overrides = {})
      ci = %w[CI GITHUB_ACTIONS GITLAB_CI JENKINS_URL BUILDKITE CIRCLECI TF_BUILD TRAVIS].to_h { |key| [key, nil] }
      ci.merge('HEADLESS' => 'true', 'VIDEO' => 'off', 'TRACE' => 'off', 'RAIDER_CACHE_DIR' => cache_dir,
               'RAIDER_TOKEN' => nil, 'RAIDER_ENDPOINT' => nil, 'SCREENSHOTS' => nil, 'SHOT_VARIANT' => nil).merge(overrides)
    end

    def use_browser(name)
      opted_in = ENV.fetch('RAIDER_E2E_BROWSERS', '').split(',').map(&:strip).include?(name)
      skip "set RAIDER_E2E_BROWSERS=#{name} to run screenshot comparison on #{name}" unless name == 'chrome' || opted_in
      skip 'Microsoft Edge is not installed' if name == 'edge' && !File.directory?('/Applications/Microsoft Edge.app')
      skip "#{name} is not installed" unless name == 'edge' || browser_installed?(name == 'firefox' ? 'firefox' : 'chrome')
      @browser_name = name
      original_config
      edge_args = "  edge:\n    - no-sandbox\n"
      File.write(config_path, original_config.sub(/^browser: .*$/, "browser: #{name}").sub(/^  firefox:/, "#{edge_args}  firefox:"))
    end

    attr_reader :browser_name

    def attachment_names(project)
      results(project).flat_map { |result| result['attachments'].map { |attachment| attachment['name'] } }
    end

    def comparison_names(project)
      attachment_names(project).grep(/\Acomparison:/)
    end

    def baseline_path
      File.join(project, baseline)
    end

    def write_rspec_spec
      File.write(File.join(project, 'spec/screenshot_comparison_spec.rb'), <<~SPEC)
        # frozen_string_literal: true

        require_relative '../helpers/spec_helper'

        describe 'Screenshot comparison' do
          it 'matches home' do
            driver.navigate.to('#{shot_page}')
            driver.execute_script("#{recolour}") if ENV['SHOT_VARIANT'] == 'changed'
            match_screenshot('home')
          end
        end
      SPEC
    end

    def write_cucumber_feature
      File.write(File.join(project, 'features/screenshot_comparison.feature'), <<~FEATURE)
        Feature: Screenshot comparison

        Scenario: Home matches
            Given the screenshot page is open
            Then the page matches the "home" screenshot
      FEATURE
      File.write(File.join(project, 'features/step_definitions/screenshot_comparison_steps.rb'), <<~STEPS)
        # frozen_string_literal: true

        Given('the screenshot page is open') do
          driver.navigate.to('#{shot_page}')
          driver.execute_script("#{recolour}") if ENV['SHOT_VARIANT'] == 'changed'
        end

        Then('the page matches the {string} screenshot') do |name|
          match_screenshot(name)
        end
      STEPS
    end

    # Every failure message in run.json, as text.
    def failure_text(project)
      results(project).to_json
    end

    def expect_ok(run)
      expect(run[:exit_code]).to eq(0), "STDOUT: #{run[:stdout]}\nSTDERR: #{run[:stderr]}"
    end

    def expect_failed(run)
      expect(run[:exit_code]).to eq(1), "STDOUT: #{run[:stdout]}\nSTDERR: #{run[:stderr]}"
    end

    # The five runs of the plan, in order; each block is one run of the generated test.
    def walk_through(command)
      run = proc do |overrides = {}|
        FileUtils.rm_rf(File.join(project, 'raider-results'))
        run_in_project(project, command, env: shot_env(overrides), timeout: 300)
      end

      expect_ok(run.call) # 1: creates the baseline
      expect(File).to exist(baseline_path)
      expect(File.binread(baseline_path)).to start_with("\x89PNG".b)
      first_bytes = File.binread(baseline_path)

      expect_ok(run.call) # 2: matches
      expect(comparison_names(project)).to be_empty

      different = run.call('SHOT_VARIANT' => 'changed') # 3: differs
      expect_failed(different)
      expect(comparison_names(project)).to include('comparison:home:expected', 'comparison:home:actual', 'comparison:home:diff')
      expect(failure_text(project)).to include(baseline)
      expect(File.binread(baseline_path)).to eq(first_bytes)
      expect(different[:stderr].scan('[screenshots] this raider_reporter has no comparison method').size).to be <= 1

      FileUtils.rm_f(baseline_path) # 4: CI without a baseline
      missing = run.call('CI' => '1')
      expect_failed(missing)
      expect(File).not_to exist(baseline_path)
      expect(failure_text(project)).to include('no baseline')

      expect_ok(run.call('SCREENSHOTS' => 'update')) # 5: update rewrites
      expect(File).to exist(baseline_path)
      expect_ok(run.call('SHOT_VARIANT' => 'changed', 'SCREENSHOTS' => 'update'))
      expect(File.binread(baseline_path)).not_to eq(first_bytes)
    end

    %w[chrome edge firefox].each do |name|
      describe "Selenium + RSpec on headless #{name}" do
        let(:project) { 'video_rspec_selenium' }

        before do
          generate_video_project('rspec', 'selenium')
          use_browser(name)
          write_rspec_spec
        end

        it 'creates, matches, fails with images, refuses on CI and updates', :aggregate_failures do
          walk_through('bundle exec rspec spec/screenshot_comparison_spec.rb')
        end
      end

      describe "Selenium + Cucumber on headless #{name}" do
        let(:project) { 'video_cucumber_selenium' }

        before do
          generate_video_project('cucumber', 'selenium')
          use_browser(name)
          write_cucumber_feature
        end

        it 'creates, matches, fails with images, refuses on CI and updates', :aggregate_failures do
          walk_through('bundle exec cucumber features/screenshot_comparison.feature')
        end
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
    it 'compiles each partial once and reuses it on the second generation' do
      require_relative '../../lib/generators/generator'

      Generator.clear_template_cache
      compiled = []
      allow_any_instance_of(TemplateRenderer::PartialCache).to(
        receive(:compile_template).and_wrap_original { |original, *args| compiled << args.first && original.call(*args) }
      )

      %w[test_cache_1 test_cache_2].map do |name|
        before = compiled.size
        generate_framework(create_settings(framework: 'rspec', automation: 'selenium').merge(name:))
        compiled.size - before
      end => [first, second]

      expect(first).to be_positive
      expect(second).to eq(0)
      expect(Generator.template_cache_stats[:size]).to be_positive
    ensure
      FileUtils.rm_rf(%w[test_cache_1 test_cache_2])
    end
  end
end
