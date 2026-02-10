# frozen_string_literal: true

require_relative 'spec_helper'
require 'timeout'
require 'open3'

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
      Timeout.timeout(timeout) do
        stdout, stderr, status = Open3.capture3(command)
        result[:stdout] = stdout
        result[:stderr] = stderr
        result[:exit_code] = status.exitstatus
        result[:success] = status.success?
      end
    end

    result
  rescue Timeout::Error
    result[:stderr] = "Command timed out after #{timeout} seconds"
    result[:exit_code] = -1
    result
  end

  # Helper to install dependencies
  def bundle_install(project_name)
    puts "\n📦 Installing dependencies for #{project_name}..."
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
    result = run_in_project(project_name, 'bundle exec cucumber features/ --format pretty', timeout: 120)

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

    it 'runs generated RSpec tests successfully', :slow do
      skip 'Bundle install failed' unless bundle_install(project)

      result = run_rspec(project)

      expect(result[:success]).to be(true),
                                  "RSpec tests failed with exit code #{result[:exit_code]}.\n" \
                                  "STDOUT: #{result[:stdout]}\n" \
                                  "STDERR: #{result[:stderr]}"
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

    describe 'Axe + Cucumber' do
      include_examples 'executable cucumber project', 'cucumber_axe'
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
      end
    end
  end

  context 'Visual Testing Frameworks (structure validation only)' do
    describe 'Applitools + RSpec' do
      it 'generates valid project structure with visual helper' do
        expect(File).to exist('rspec_applitools/helpers/visual_helper.rb')
        expect(File).to exist('rspec_applitools/helpers/spec_helper.rb')
      end

      it 'includes Applitools dependencies' do
        gemfile = File.read('rspec_applitools/Gemfile')
        expect(gemfile).to include('eyes_selenium')
      end

      it 'has valid Ruby syntax in generated files' do
        result = run_in_project('rspec_applitools', 'ruby -c helpers/visual_helper.rb')
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
