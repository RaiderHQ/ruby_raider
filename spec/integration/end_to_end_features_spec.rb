# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'content/content_helper'
require_relative '../../lib/commands/scaffolding_commands'
require_relative '../../lib/scaffolding/scaffolding'
require 'timeout'
require 'open3'

# End-to-end tests for features (retry, tags, addons, CI, debug, etc.)
# These tests generate complete projects with feature flags and verify they are executable.
describe 'End-to-End Feature Validation' do
  include ContentHelper
  def run_in_project(project_name, command, timeout: 300)
    result = { success: false, stdout: '', stderr: '', exit_code: nil }

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

  def bundle_install(project_name)
    run_in_project(project_name, 'bundle install --quiet', timeout: 180)[:success]
  end

  def run_rspec(project_name)
    run_in_project(project_name, 'bundle exec rspec spec/ --format documentation', timeout: 120)
  end

  # Validate Ruby files, excluding abstract base classes (pre-existing template without frozen_string_literal)
  def ruby_files(project_name)
    Dir.glob("#{project_name}/**/*.rb").reject { |f| f.include?('/abstract/') }
  end

  # --- Shared examples ---

  shared_examples 'executable rspec project with features' do |project_name|
    it 'installs dependencies successfully', :slow do
      expect(bundle_install(project_name)).to be true
    end

    it 'runs generated RSpec tests successfully', :slow do
      skip 'Bundle install failed' unless bundle_install(project_name)

      result = run_rspec(project_name)
      expect(result[:success]).to be(true),
                                  "RSpec tests failed:\nSTDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
    end

    it 'has rake tasks available', :slow do
      skip 'Bundle install failed' unless bundle_install(project_name)

      result = run_in_project(project_name, 'bundle exec rake -T', timeout: 30)
      expect(result[:success]).to be true
      expect(result[:stdout]).to include('spec')
    end
  end

  shared_examples 'project with valid file structure' do |project_name|
    it 'has Gemfile' do
      expect(File).to exist("#{project_name}/Gemfile")
    end

    it 'has Rakefile' do
      expect(File).to exist("#{project_name}/Rakefile")
    end

    it 'has spec_helper' do
      expect(File).to exist("#{project_name}/helpers/spec_helper.rb")
    end

    it 'has .rspec' do
      expect(File).to exist("#{project_name}/.rspec")
    end

    it 'all Ruby files have valid syntax' do
      ruby_files(project_name).each do |file|
        content = File.read(file)
        expect(content).to have_valid_ruby_syntax,
                           "#{file} has invalid syntax"
      end
    end

    it 'all Ruby files have frozen_string_literal' do
      ruby_files(project_name).each do |file|
        content = File.read(file)
        expect(content).to have_frozen_string_literal,
                           "#{file} missing frozen_string_literal"
      end
    end
  end

  # --- Feature: Retry config (C4) ---

  context 'Retry configuration' do
    it 'default rspec projects include rspec-retry gem' do
      gemfile = read_generated("#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}", 'Gemfile')
      expect(gemfile).to include("gem 'rspec-retry'")
    end

    it 'default rspec projects have retry config in spec_helper' do
      helper = read_generated("#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}", 'helpers/spec_helper.rb')
      expect(helper).to include('config.verbose_retry = true')
      expect(helper).to include("ENV.fetch('RETRY_COUNT', 0)")
    end

    it 'cucumber projects have --retry in cucumber.yml' do
      cucumber_yml = read_generated("#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}", 'cucumber.yml')
      expect(cucumber_yml).to include('--retry')
    end
  end

  # --- Feature: Tag-based rake tasks (C5) ---

  context 'Tag-based rake tasks' do
    let(:rspec_project) { "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}" }
    let(:cucumber_project) { "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}" }

    it 'rspec Rakefile has smoke task' do
      rakefile = read_generated(rspec_project, 'Rakefile')
      expect(rakefile).to include('RakeTask.new(:smoke)')
      expect(rakefile).to include("'--tag smoke'")
    end

    it 'rspec Rakefile has regression task' do
      rakefile = read_generated(rspec_project, 'Rakefile')
      expect(rakefile).to include('RakeTask.new(:regression)')
      expect(rakefile).to include("'--tag regression'")
    end

    it 'cucumber Rakefile has smoke task with cucumber tags' do
      rakefile = read_generated(cucumber_project, 'Rakefile')
      expect(rakefile).to include("'--tags @smoke'")
    end

    it 'rspec smoke rake task works', :slow do
      skip 'Bundle install needed' unless bundle_install(rspec_project)

      result = run_in_project(rspec_project, 'bundle exec rake smoke', timeout: 60)
      expect(result[:success]).to be true
    end
  end

  # --- Feature: Re-run failed tests (C6) ---

  context 'Re-run failed tests' do
    let(:rspec_project) { "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}" }
    let(:cucumber_project) { "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}" }

    it 'rspec projects have .rspec file' do
      expect(File).to exist("#{rspec_project}/.rspec")
    end

    it '.rspec includes documentation format' do
      rspec = read_generated(rspec_project, '.rspec')
      expect(rspec).to include('--format documentation')
    end

    it 'spec_helper has persistence file path' do
      helper = read_generated(rspec_project, 'helpers/spec_helper.rb')
      expect(helper).to include("config.example_status_persistence_file_path = 'spec/examples.txt'")
    end

    it '.gitignore includes spec/examples.txt' do
      gitignore = read_generated(rspec_project, '.gitignore')
      expect(gitignore).to include('spec/examples.txt')
    end

    it 'cucumber projects do not have .rspec file' do
      expect(File).not_to exist("#{cucumber_project}/.rspec")
    end
  end

  # --- Feature: Accessibility addon (axe) ---

  context 'Accessibility addon' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'e2e_axe_rspec',
        accessibility: true
      )
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'cucumber', name: 'e2e_axe_cucumber',
        accessibility: true
      )
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      %w[e2e_axe_rspec e2e_axe_cucumber].each { |n| FileUtils.rm_rf(n) }
    end

    describe 'axe + RSpec' do
      include_examples 'project with valid file structure', 'e2e_axe_rspec'

      it 'creates accessibility_spec.rb' do
        expect(File).to exist('e2e_axe_rspec/spec/accessibility_spec.rb')
      end

      it 'includes axe gems in Gemfile' do
        gemfile = File.read('e2e_axe_rspec/Gemfile')
        expect(gemfile).to include('axe')
      end

      it 'accessibility spec has valid Ruby syntax' do
        content = File.read('e2e_axe_rspec/spec/accessibility_spec.rb')
        expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
      end
    end

    describe 'axe + Cucumber' do
      it 'creates accessibility.feature' do
        expect(File).to exist('e2e_axe_cucumber/features/accessibility.feature')
      end

      it 'creates accessibility_steps.rb' do
        expect(File).to exist('e2e_axe_cucumber/features/step_definitions/accessibility_steps.rb')
      end

      it 'includes axe gems in Gemfile' do
        gemfile = File.read('e2e_axe_cucumber/Gemfile')
        expect(gemfile).to include('axe')
      end

      it 'all Ruby files have valid syntax' do
        ruby_files('e2e_axe_cucumber').each do |file|
          content = File.read(file)
          expect(content).to have_valid_ruby_syntax, "#{file} has invalid syntax"
        end
      end
    end

  end

  # --- Feature: GitHub Actions CI ---

  context 'GitHub Actions CI' do
    let(:project) { "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}" }

    it 'creates GitHub Actions workflow' do
      expect(File).to exist("#{project}/.github/workflows/test_pipeline.yml")
    end

    it 'workflow is valid YAML' do
      content = File.read("#{project}/.github/workflows/test_pipeline.yml")
      expect { YAML.safe_load(content) }.not_to raise_error
    end

    it 'workflow includes rspec run step' do
      content = File.read("#{project}/.github/workflows/test_pipeline.yml")
      expect(content).to include('rspec')
    end
  end

  # --- Feature: Debug helper ---

  context 'Debug helper generation' do
    it 'web projects include debug_helper.rb' do
      expect(File).to exist("#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}/helpers/debug_helper.rb")
    end

    it 'debug helper has valid Ruby syntax' do
      content = File.read("#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}/helpers/debug_helper.rb")
      expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
    end

    it 'debug helper defines DebugHelper module' do
      content = File.read("#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}/helpers/debug_helper.rb")
      expect(content).to include('module DebugHelper')
    end

    it 'config.yml includes debug section' do
      config = YAML.load_file("#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}/config/config.yml")
      expect(config).to have_key('debug')
      expect(config['debug']['enabled']).to be false
    end
  end

  # --- Feature: Template override (C3) ---

  context 'Template override system' do
    let(:project) { "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}" }

    it 'uses override template when present' do
      original_dir = Dir.pwd
      Dir.chdir(project)
      FileUtils.mkdir_p('.ruby_raider/templates')

      File.write('.ruby_raider/templates/page_object.tt', <<~ERB)
        # frozen_string_literal: true

        class <%= page_class_name %> < Page
          # E2E_CUSTOM_OVERRIDE_MARKER
        end
      ERB

      Scaffolding.new(%w[e2e_override]).generate_page
      content = File.read('page_objects/pages/e2e_override.rb')
      expect(content).to include('E2E_CUSTOM_OVERRIDE_MARKER')
      expect(content).to include('class E2eOverridePage < Page')
    ensure
      FileUtils.rm_f('page_objects/pages/e2e_override.rb')
      FileUtils.rm_rf('.ruby_raider')
      Dir.chdir(original_dir)
    end

    it 'falls back to default when no override present' do
      original_dir = Dir.pwd
      Dir.chdir(project)

      Scaffolding.new(%w[e2e_default]).generate_page
      content = File.read('page_objects/pages/e2e_default.rb')
      expect(content).not_to include('E2E_CUSTOM_OVERRIDE_MARKER')
      expect(content).to include('class E2eDefaultPage < Page')
    ensure
      FileUtils.rm_f('page_objects/pages/e2e_default.rb')
      Dir.chdir(original_dir)
    end
  end
end
