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

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid github pipeline', name
    include_examples 'github cucumber pipeline', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
  end
end
