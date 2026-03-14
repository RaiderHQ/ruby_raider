# frozen_string_literal: true

require 'fileutils'
require_relative '../../../lib/generators/invoke_generators'

describe 'Skip flags for project generation' do
  include InvokeGenerators

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    %w[skip_allure_test skip_video_test skip_ci_test skip_all_test].each do |name|
      FileUtils.rm_rf(name)
    end
  end

  describe '--skip-allure' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'skip_allure_test', skip_allure: true
      )
    end

    it 'does not generate allure_helper.rb' do
      expect(File).not_to exist('skip_allure_test/helpers/allure_helper.rb')
    end

    it 'does not create allure-results directory' do
      expect(File).not_to exist('skip_allure_test/allure-results')
    end

    it 'does not include allure gems in Gemfile' do
      gemfile = File.read('skip_allure_test/Gemfile')
      expect(gemfile).not_to include('allure-rspec')
      expect(gemfile).not_to include('allure-ruby-commons')
    end

    it 'does not reference AllureHelper in spec_helper' do
      helper = File.read('skip_allure_test/helpers/spec_helper.rb')
      expect(helper).not_to include('allure_helper')
      expect(helper).not_to include('AllureHelper')
    end

    it 'does not include allure-results in .gitignore' do
      gitignore = File.read('skip_allure_test/.gitignore')
      expect(gitignore).not_to include('allure-results')
    end

    it 'still generates spec_helper.rb with valid syntax' do
      helper = File.read('skip_allure_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end

    it 'still has rspec-retry config' do
      helper = File.read('skip_allure_test/helpers/spec_helper.rb')
      expect(helper).to include('rspec/retry')
    end
  end

  describe '--skip-video' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'skip_video_test', skip_video: true
      )
    end

    it 'does not generate video_helper.rb' do
      expect(File).not_to exist('skip_video_test/helpers/video_helper.rb')
    end

    it 'does not reference video_helper in spec_helper' do
      helper = File.read('skip_video_test/helpers/spec_helper.rb')
      expect(helper).not_to include('video_helper')
    end

    it 'still generates allure_helper.rb' do
      expect(File).to exist('skip_video_test/helpers/allure_helper.rb')
    end

    it 'still generates spec_helper.rb with valid syntax' do
      helper = File.read('skip_video_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end

  describe '--skip-ci' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'skip_ci_test',
        ci_platform: 'github', skip_ci: true
      )
    end

    it 'does not generate CI pipeline files' do
      expect(File).not_to exist('skip_ci_test/.github')
    end

    it 'still generates the project' do
      expect(File).to exist('skip_ci_test/Gemfile')
      expect(File).to exist('skip_ci_test/helpers/spec_helper.rb')
    end
  end

  describe 'all skip flags combined' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(
        automation: 'selenium', framework: 'rspec', name: 'skip_all_test',
        ci_platform: 'github', skip_ci: true, skip_allure: true, skip_video: true
      )
    end

    it 'does not generate allure_helper.rb' do
      expect(File).not_to exist('skip_all_test/helpers/allure_helper.rb')
    end

    it 'does not generate video_helper.rb' do
      expect(File).not_to exist('skip_all_test/helpers/video_helper.rb')
    end

    it 'does not generate CI files' do
      expect(File).not_to exist('skip_all_test/.github')
    end

    it 'still generates core project files' do
      expect(File).to exist('skip_all_test/Gemfile')
      expect(File).to exist('skip_all_test/Rakefile')
      expect(File).to exist('skip_all_test/helpers/spec_helper.rb')
      expect(File).to exist('skip_all_test/helpers/driver_helper.rb')
    end

    it 'generates spec_helper.rb with valid syntax' do
      helper = File.read('skip_all_test/helpers/spec_helper.rb')
      expect { RubyVM::InstructionSequence.compile(helper) }.not_to raise_error
    end
  end
end
