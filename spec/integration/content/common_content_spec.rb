# frozen_string_literal: true

require_relative 'content_helper'

describe 'Common file content' do
  # --- Rakefile ---

  shared_examples 'valid rakefile' do |project_name|
    subject(:rakefile) { read_generated(project_name, 'Rakefile') }

    it 'has raider version task' do
      expect(rakefile).to include('task :raider')
    end
  end

  shared_examples 'rspec rakefile with tag tasks' do |project_name|
    subject(:rakefile) { read_generated(project_name, 'Rakefile') }

    it 'requires rspec/core/rake_task' do
      expect(rakefile).to include("require 'rspec/core/rake_task'")
    end

    it 'defines spec task' do
      expect(rakefile).to include('RakeTask.new(:spec)')
    end

    it 'defines smoke task' do
      expect(rakefile).to include('RakeTask.new(:smoke)')
      expect(rakefile).to include("'--tag smoke'")
    end

    it 'defines regression task' do
      expect(rakefile).to include('RakeTask.new(:regression)')
      expect(rakefile).to include("'--tag regression'")
    end

    it 'sets default task to spec' do
      expect(rakefile).to include('task default: :spec')
    end

    it 'does not include cucumber tasks' do
      expect(rakefile).not_to include('Cucumber::Rake::Task')
    end
  end

  shared_examples 'cucumber rakefile with tag tasks' do |project_name|
    subject(:rakefile) { read_generated(project_name, 'Rakefile') }

    it 'requires cucumber/rake/task' do
      expect(rakefile).to include("require 'cucumber/rake/task'")
    end

    it 'defines features task' do
      expect(rakefile).to include('Rake::Task.new(:features)')
    end

    it 'defines smoke task' do
      expect(rakefile).to include('Rake::Task.new(:smoke)')
      expect(rakefile).to include("'--tags @smoke'")
    end

    it 'defines regression task' do
      expect(rakefile).to include('Rake::Task.new(:regression)')
      expect(rakefile).to include("'--tags @regression'")
    end

    it 'sets default task to features' do
      expect(rakefile).to include('task default: :features')
    end

    it 'does not include rspec tasks' do
      expect(rakefile).not_to include('RSpec::Core::RakeTask')
    end
  end

  shared_examples 'minitest rakefile with default task' do |project_name|
    subject(:rakefile) { read_generated(project_name, 'Rakefile') }

    it 'requires rake/testtask' do
      expect(rakefile).to include("require 'rake/testtask'")
    end

    it 'defines test task' do
      expect(rakefile).to include('Rake::TestTask.new(:test)')
    end

    it 'sets default task to test' do
      expect(rakefile).to include('task default: :test')
    end
  end

  # --- .rspec file ---

  shared_examples 'has rspec dotfile' do |project_name|
    subject(:rspec_file) { read_generated(project_name, '.rspec') }

    it 'exists' do
      expect(File).to exist(File.join(project_name, '.rspec'))
    end

    it 'requires spec_helper' do
      expect(rspec_file).to include('--require helpers/spec_helper')
    end

    it 'uses documentation format' do
      expect(rspec_file).to include('--format documentation')
    end
  end

  shared_examples 'no rspec dotfile' do |project_name|
    it 'does not have .rspec file' do
      expect(File).not_to exist(File.join(project_name, '.rspec'))
    end
  end

  # --- .gitignore ---

  shared_examples 'rspec gitignore' do |project_name|
    subject(:gitignore) { read_generated(project_name, '.gitignore') }

    it 'includes allure-results' do
      expect(gitignore).to include('allure-results')
    end

    it 'includes spec/examples.txt' do
      expect(gitignore).to include('spec/examples.txt')
    end
  end

  shared_examples 'non-rspec gitignore' do |project_name|
    subject(:gitignore) { read_generated(project_name, '.gitignore') }

    it 'includes allure-results' do
      expect(gitignore).to include('allure-results')
    end

    it 'does not include spec/examples.txt' do
      expect(gitignore).not_to include('spec/examples.txt')
    end
  end

  # --- Spec helper retry config (C4) ---

  shared_examples 'spec helper with retry config' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'requires rspec/retry' do
      expect(helper).to include("require 'rspec/retry'")
    end

    it 'enables verbose retry' do
      expect(helper).to include('config.verbose_retry = true')
    end

    it 'enables failure messages display' do
      expect(helper).to include('config.display_try_failure_messages = true')
    end

    it 'sets retry count from env' do
      expect(helper).to include("config.default_retry_count = ENV.fetch('RETRY_COUNT', 0).to_i")
    end

    it 'has example_status_persistence_file_path' do
      expect(helper).to include("config.example_status_persistence_file_path = 'spec/examples.txt'")
    end
  end

  # --- Gemfile retry gem (C4) ---

  shared_examples 'gemfile with rspec-retry' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes rspec-retry gem' do
      expect(gemfile).to include("gem 'rspec-retry'")
    end
  end

  shared_examples 'gemfile without rspec-retry' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'does not include rspec-retry gem' do
      expect(gemfile).not_to include("gem 'rspec-retry'")
    end
  end

  # --- Cucumber retry config (C4) ---

  shared_examples 'cucumber config with retry' do |project_name|
    subject(:cucumber_yml) { read_generated(project_name, 'cucumber.yml') }

    it 'includes --retry flag' do
      expect(cucumber_yml).to include('--retry')
    end
  end

  # --- RSpec contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'rspec rakefile with tag tasks', name
    it_behaves_like 'has rspec dotfile', name
    it_behaves_like 'rspec gitignore', name
    it_behaves_like 'spec helper with retry config', name
    it_behaves_like 'gemfile with rspec-retry', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'rspec rakefile with tag tasks', name
    it_behaves_like 'has rspec dotfile', name
    it_behaves_like 'rspec gitignore', name
    it_behaves_like 'spec helper with retry config', name
    it_behaves_like 'gemfile with rspec-retry', name
  end

  context 'with rspec and capybara' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CAPYBARA}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'rspec rakefile with tag tasks', name
    it_behaves_like 'has rspec dotfile', name
    it_behaves_like 'rspec gitignore', name
    it_behaves_like 'spec helper with retry config', name
    it_behaves_like 'gemfile with rspec-retry', name
  end

  # --- Cucumber contexts ---

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'cucumber rakefile with tag tasks', name
    it_behaves_like 'no rspec dotfile', name
    it_behaves_like 'non-rspec gitignore', name
    it_behaves_like 'gemfile without rspec-retry', name
    it_behaves_like 'cucumber config with retry', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'cucumber rakefile with tag tasks', name
    it_behaves_like 'no rspec dotfile', name
    it_behaves_like 'non-rspec gitignore', name
    it_behaves_like 'gemfile without rspec-retry', name
    it_behaves_like 'cucumber config with retry', name
  end

  context 'with cucumber and capybara' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CAPYBARA}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'cucumber rakefile with tag tasks', name
    it_behaves_like 'no rspec dotfile', name
    it_behaves_like 'non-rspec gitignore', name
    it_behaves_like 'gemfile without rspec-retry', name
    it_behaves_like 'cucumber config with retry', name
  end

  # --- Minitest contexts ---

  context 'with minitest and selenium' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'minitest rakefile with default task', name
    it_behaves_like 'no rspec dotfile', name
    it_behaves_like 'non-rspec gitignore', name
    it_behaves_like 'gemfile without rspec-retry', name
  end

  context 'with minitest and watir' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'minitest rakefile with default task', name
    it_behaves_like 'no rspec dotfile', name
    it_behaves_like 'non-rspec gitignore', name
    it_behaves_like 'gemfile without rspec-retry', name
  end

  context 'with minitest and capybara' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}"
    it_behaves_like 'valid rakefile', name
    it_behaves_like 'minitest rakefile with default task', name
    it_behaves_like 'no rspec dotfile', name
    it_behaves_like 'non-rspec gitignore', name
    it_behaves_like 'gemfile without rspec-retry', name
  end
end
