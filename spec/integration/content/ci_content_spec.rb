# frozen_string_literal: true

require 'yaml'
require_relative 'content_helper'

describe 'CI pipeline content' do
  shared_examples 'valid github pipeline' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'is valid YAML' do
      expect { YAML.safe_load(pipeline) }.not_to raise_error
    end

    it 'has name' do
      expect(pipeline).to match(/^name:/)
    end

    it 'has jobs section' do
      expect(pipeline).to include('jobs:')
    end

    it 'sets up Ruby' do
      expect(pipeline).to include('ruby')
    end

    it 'installs dependencies' do
      expect(pipeline).to include('bundler-cache: true').or include('bundle install')
    end
  end

  shared_examples 'github rspec pipeline' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'runs rspec' do
      expect(pipeline).to include('rspec')
    end
  end

  shared_examples 'github cucumber pipeline' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'runs cucumber' do
      expect(pipeline).to include('cucumber')
    end
  end

  shared_examples 'github triggers' do |project_name, file|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:triggers) { YAML.safe_load(pipeline)[true] }

    it 'triggers on push to main and master' do
      expect(triggers['push']['branches']).to include('main', 'master')
    end

    it 'triggers on pull_request' do
      expect(triggers).to have_key('pull_request')
    end

    it 'triggers on workflow_dispatch' do
      expect(triggers).to have_key('workflow_dispatch')
    end
  end

  shared_examples 'github raider wiring' do |project_name, file, runner = 'rspec'|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:steps) { YAML.safe_load(pipeline)['jobs'].values.flat_map { |job| job['steps'] } }

    let(:test_steps) do
      steps.select { |step| step['run'].to_s.include?(runner) || step['with'].to_h['script'].to_s.include?(runner) }
    end

    it 'passes Raider settings to every test step' do
      expect(test_steps).not_to be_empty
      test_steps.each do |step|
        expect(step['env']).to include('RAIDER_TOKEN' => '${{ secrets.RAIDER_TOKEN }}',
                                       'RAIDER_ENDPOINT' => '${{ vars.RAIDER_ENDPOINT }}')
      end
    end

    it 'uploads raider-results as an artifact even on failure in every job' do
      uploads = steps.select { |step| step['uses'] == 'actions/upload-artifact@v4' }
      expect(uploads.size).to eq(YAML.safe_load(pipeline)['jobs'].except('raider-comment').size)
      uploads.each do |upload|
        expect(upload['with']['path']).to eq('raider-results/')
        expect(upload['if']).to eq('always()')
      end
    end
  end

  shared_examples 'github raider-comment job' do |project_name, file, test_jobs|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:jobs) { YAML.safe_load(pipeline)['jobs'] }
    let(:job) { jobs['raider-comment'] }

    it 'is a valid workflow with exactly the expected jobs' do
      expect(jobs.keys).to match_array(test_jobs + ['raider-comment'])
    end

    it 'needs every test job' do
      expect(job['needs']).to match_array(test_jobs)
    end

    it 'runs always, on pull requests only' do
      expect(job['if']).to eq("always() && github.event_name == 'pull_request'")
      expect(job['runs-on']).to eq('ubuntu-latest')
    end

    it 'has the least permissions required' do
      expect(job['permissions']).to eq('contents' => 'read', 'pull-requests' => 'write', 'statuses' => 'write')
    end

    it 'checks out, sets up the same Ruby as the test jobs and comments' do
      steps = job['steps']
      expect(steps[0]).to eq('uses' => 'actions/checkout@v4')
      expect(steps[1]['uses']).to eq('ruby/setup-ruby@v1')
      test_ruby = jobs.values_at(*test_jobs).flat_map { |j| j['steps'] }
                      .find { |step| step['uses'] == 'ruby/setup-ruby@v1' }['with']['ruby-version']
      expect(steps[1]['with']).to eq('ruby-version' => test_ruby, 'bundler-cache' => true)
      expect(steps[2]).to eq('name' => 'Comment Raider results on the pull request',
                             'run' => 'bundle exec raider-reporter comment',
                             'env' => { 'RAIDER_TOKEN' => '${{ secrets.RAIDER_TOKEN }}',
                                        'RAIDER_ENDPOINT' => '${{ vars.RAIDER_ENDPOINT }}',
                                        'GITHUB_TOKEN' => '${{ secrets.GITHUB_TOKEN }}' })
      expect(steps.size).to eq(3)
    end
  end

  shared_examples 'github allure steps' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'keeps the Allure steps' do
      expect(pipeline).to include('simple-elf/allure-report-action', 'peaceiris/actions-gh-pages')
    end
  end

  shared_examples 'github without allure steps' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'has no Allure report or gh-pages steps' do
      expect(pipeline).not_to match(/allure|gh-pages/i)
    end
  end

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml'
    include_examples 'github raider-comment job', name, 'test_pipeline.yml', %w[build]
    include_examples 'github allure steps', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid github pipeline', name
    include_examples 'github cucumber pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml', 'cucumber'
    include_examples 'github raider-comment job', name, 'test_pipeline.yml', %w[build]
    include_examples 'github without allure steps', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml'
    include_examples 'github raider-comment job', name, 'test_pipeline.yml', %w[build]
    include_examples 'github allure steps', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'valid github pipeline', name
    include_examples 'github cucumber pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml', 'cucumber'
    include_examples 'github raider-comment job', name, 'test_pipeline.yml', %w[build]
    include_examples 'github without allure steps', name
  end

  appium_jobs = { 'android' => %w[android-tests], 'ios' => %w[ios-tests],
                  'cross_platform' => %w[ios-tests android-tests] }

  appium_jobs.each do |automation, test_jobs|
    context "with rspec and #{automation}" do
      name = "#{FrameworkIndex::RSPEC}_#{automation}"
      include_examples 'github raider-comment job', name, 'appium_pipeline.yml', test_jobs
      include_examples 'github triggers', name, 'appium_pipeline.yml'
      include_examples 'github raider wiring', name, 'appium_pipeline.yml'
    end

    context "with cucumber and #{automation}" do
      name = "#{FrameworkIndex::CUCUMBER}_#{automation}"
      include_examples 'github triggers', name, 'appium_pipeline.yml'
      include_examples 'github raider wiring', name, 'appium_pipeline.yml', 'cucumber'
      include_examples 'github raider-comment job', name, 'appium_pipeline.yml', test_jobs
    end
  end
end
