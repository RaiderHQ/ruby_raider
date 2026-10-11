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

  shared_examples 'github raider wiring' do |project_name, file|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:steps) { YAML.safe_load(pipeline)['jobs'].values.flat_map { |job| job['steps'] } }

    it 'passes Raider settings to the test step' do
      expect(pipeline).to include('RAIDER_TOKEN: ${{ secrets.RAIDER_TOKEN }}')
      expect(pipeline).to include('RAIDER_ENDPOINT: ${{ vars.RAIDER_ENDPOINT }}')
    end

    it 'uploads raider-results as an artifact even on failure' do
      upload = steps.find { |step| step['uses'] == 'actions/upload-artifact@v4' }
      expect(upload['with']['path']).to eq('raider-results/')
      expect(upload['if']).to eq('always()')
    end
  end

  shared_examples 'github without raider wiring' do |project_name, file|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    it 'has no Raider settings or artifact' do
      expect(pipeline).not_to include('RAIDER_')
      expect(pipeline).not_to include('raider-results')
    end
  end

  shared_examples 'github allure steps' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'keeps the Allure steps' do
      expect(pipeline).to include('simple-elf/allure-report-action', 'peaceiris/actions-gh-pages')
    end
  end

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml'
    include_examples 'github allure steps', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid github pipeline', name
    include_examples 'github cucumber pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github without raider wiring', name, 'test_pipeline.yml'
    include_examples 'github allure steps', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml'
    include_examples 'github allure steps', name
  end

  %w[android ios cross_platform].each do |automation|
    context "with rspec and #{automation}" do
      name = "#{FrameworkIndex::RSPEC}_#{automation}"
      include_examples 'github triggers', name, 'appium_pipeline.yml'
      include_examples 'github raider wiring', name, 'appium_pipeline.yml'
    end

    context "with cucumber and #{automation}" do
      name = "#{FrameworkIndex::CUCUMBER}_#{automation}"
      include_examples 'github triggers', name, 'appium_pipeline.yml'
      include_examples 'github without raider wiring', name, 'appium_pipeline.yml'
    end
  end
end
