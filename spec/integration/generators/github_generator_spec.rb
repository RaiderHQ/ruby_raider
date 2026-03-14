# frozen_string_literal: true

require_relative '../../../lib/generators/infrastructure/github_generator'
require_relative '../spec_helper'

describe GithubGenerator do
  shared_examples 'generates github actions' do |name|
    it 'creates a github infrastructure file' do
      expect(File).to exist("#{name}/.github/workflows/test_pipeline.yml")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'generates github actions', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and watir' do
    include_examples 'generates github actions', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with cucumber and selenium' do
    include_examples 'generates github actions', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
  end

  context 'with cucumber and watir' do
    include_examples 'generates github actions', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end
end
