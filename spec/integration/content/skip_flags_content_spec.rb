# frozen_string_literal: true

require_relative 'content_helper'
require 'fileutils'

describe 'Skip flags content validation' do
  include InvokeGenerators

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    {
      'skip_allure_content' => { skip_allure: true },
      'skip_video_content' => { skip_video: true },
      'skip_ci_content' => { skip_ci: true, ci_platform: 'github' },
      'skip_all_content' => { skip_allure: true, skip_video: true, skip_ci: true, ci_platform: 'github' }
    }.each do |name, flags|
      InvokeGenerators.generate_framework(
        { automation: 'selenium', framework: 'rspec', name: name }.merge(flags)
      )
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    %w[skip_allure_content skip_video_content skip_ci_content skip_all_content].each do |name|
      FileUtils.rm_rf(name)
    end
  end

  # --- skip_allure content validation ---

  describe '--skip-allure file content' do
    let(:name) { 'skip_allure_content' }

    it 'Gemfile excludes allure gems' do
      gemfile = read_generated(name, 'Gemfile')
      expect(gemfile).not_to include('allure-rspec')
      expect(gemfile).not_to include('allure-ruby-commons')
    end

    it 'Gemfile still includes core gems' do
      gemfile = read_generated(name, 'Gemfile')
      expect(gemfile).to include("gem 'rake'")
      expect(gemfile).to include("gem 'rspec'")
      expect(gemfile).to include("gem 'selenium-webdriver'")
      expect(gemfile).to include("gem 'rspec-retry'")
    end

    it 'spec_helper does not reference AllureHelper' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).not_to include('AllureHelper')
      expect(helper).not_to include('allure_helper')
    end

    it 'spec_helper still has retry config' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).to include("require 'rspec/retry'")
      expect(helper).to include('config.verbose_retry = true')
      expect(helper).to include("config.default_retry_count = ENV.fetch('RETRY_COUNT', 0).to_i")
    end

    it 'spec_helper has valid Ruby syntax' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).to have_valid_ruby_syntax
    end

    it '.gitignore excludes allure-results' do
      gitignore = read_generated(name, '.gitignore')
      expect(gitignore).not_to include('allure-results')
    end

    it '.gitignore still includes spec/examples.txt' do
      gitignore = read_generated(name, '.gitignore')
      expect(gitignore).to include('spec/examples.txt')
    end

    it 'Rakefile still has tag tasks' do
      rakefile = read_generated(name, 'Rakefile')
      expect(rakefile).to include('RakeTask.new(:smoke)')
      expect(rakefile).to include('RakeTask.new(:regression)')
    end

    it '.rspec file still exists with correct content' do
      rspec = read_generated(name, '.rspec')
      expect(rspec).to include('--require helpers/spec_helper')
      expect(rspec).to include('--format documentation')
    end
  end

  # --- skip_video content validation ---

  describe '--skip-video file content' do
    let(:name) { 'skip_video_content' }

    it 'spec_helper does not reference video_helper' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).not_to include('video_helper')
    end

    it 'spec_helper still includes AllureHelper' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).to include('AllureHelper')
    end

    it 'spec_helper has valid Ruby syntax' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).to have_valid_ruby_syntax
    end

    it 'Gemfile still includes allure gems' do
      gemfile = read_generated(name, 'Gemfile')
      expect(gemfile).to include("gem 'allure-rspec'")
    end
  end

  # --- skip_ci content validation ---

  describe '--skip-ci file content' do
    let(:name) { 'skip_ci_content' }

    it 'does not generate GitHub Actions directory' do
      expect(File).not_to exist("#{name}/.github")
    end

    it 'still generates Gemfile with all gems' do
      gemfile = read_generated(name, 'Gemfile')
      expect(gemfile).to include("gem 'rspec'")
      expect(gemfile).to include("gem 'allure-rspec'")
      expect(gemfile).to include("gem 'rspec-retry'")
    end

    it 'still generates all helpers' do
      expect(File).to exist("#{name}/helpers/spec_helper.rb")
      expect(File).to exist("#{name}/helpers/allure_helper.rb")
      expect(File).to exist("#{name}/helpers/video_helper.rb")
      expect(File).to exist("#{name}/helpers/driver_helper.rb")
    end
  end

  # --- all skip flags combined ---

  describe 'all skip flags combined' do
    let(:name) { 'skip_all_content' }

    it 'Gemfile has no allure gems' do
      gemfile = read_generated(name, 'Gemfile')
      expect(gemfile).not_to include('allure')
    end

    it 'Gemfile still has core gems' do
      gemfile = read_generated(name, 'Gemfile')
      expect(gemfile).to include("gem 'rspec'")
      expect(gemfile).to include("gem 'selenium-webdriver'")
      expect(gemfile).to include("gem 'rspec-retry'")
    end

    it 'has no allure_helper.rb' do
      expect(File).not_to exist("#{name}/helpers/allure_helper.rb")
    end

    it 'has no video_helper.rb' do
      expect(File).not_to exist("#{name}/helpers/video_helper.rb")
    end

    it 'has no CI files' do
      expect(File).not_to exist("#{name}/.github")
    end

    it 'spec_helper has no allure or video references' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).not_to include('AllureHelper')
      expect(helper).not_to include('allure_helper')
      expect(helper).not_to include('video_helper')
    end

    it 'spec_helper has valid Ruby syntax' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).to have_valid_ruby_syntax
    end

    it 'spec_helper still has retry and persistence config' do
      helper = read_generated(name, 'helpers/spec_helper.rb')
      expect(helper).to include("require 'rspec/retry'")
      expect(helper).to include("config.example_status_persistence_file_path = 'spec/examples.txt'")
    end

    it 'Rakefile still has tag tasks' do
      rakefile = read_generated(name, 'Rakefile')
      expect(rakefile).to include('RakeTask.new(:smoke)')
    end

    it 'all generated .rb files have valid syntax' do
      Dir.glob("#{name}/**/*.rb").each do |file|
        content = File.read(file)
        expect(content).to have_valid_ruby_syntax,
                           "#{file} has invalid Ruby syntax"
      end
    end

    it 'all generated .rb files (except abstract) have frozen_string_literal' do
      Dir.glob("#{name}/**/*.rb").reject { |f| f.include?('/abstract/') }.each do |file|
        content = File.read(file)
        expect(content).to have_frozen_string_literal,
                           "#{file} is missing frozen_string_literal"
      end
    end
  end
end
