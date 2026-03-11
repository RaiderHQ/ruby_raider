# frozen_string_literal: true

require_relative '../../../lib/generators/infrastructure/github_generator'
require_relative '../spec_helper'

describe GithubGenerator do
  shared_examples 'selects github as an infrastructure option' do |name|
    it 'creates a github infrastructure file' do
      expect(File).to exist("#{name}/.github/workflows/test_pipeline.yml")
    end
  end

  shared_examples 'does not select any infrastructure option' do |name|
    it 'does not create a github infrastructure file' do
      expect(File).not_to exist("#{name}/.github/workflows/test_pipeline.yml")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'selects github as an infrastructure option', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}_#{CI_PLATFORMS[1]}"
    include_examples 'does not select any infrastructure option', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and watir' do
    include_examples 'selects github as an infrastructure option', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}_#{CI_PLATFORMS[1]}"
    include_examples 'does not select any infrastructure option', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with cucumber and selenium' do
    include_examples 'selects github as an infrastructure option', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}_#{CI_PLATFORMS[1]}"
    include_examples 'does not select any infrastructure option', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
  end

  context 'with cucumber and watir' do
    include_examples 'selects github as an infrastructure option', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}_#{CI_PLATFORMS[1]}"
    include_examples 'does not select any infrastructure option', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end
end
