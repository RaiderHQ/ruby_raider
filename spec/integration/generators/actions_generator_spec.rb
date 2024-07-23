# frozen_string_literal: true

require_relative '../../../lib/generators/actions/actions_generator'
require_relative '../spec_helper'

describe ActionsGenerator do
  shared_examples 'creates web automation framework' do |name|
    it 'creates a github actions file' do
      expect(File).to exist("#{name}/.github/workflows/test_pipeline.yml")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates web automation framework', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'creates web automation framework', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates web automation framework', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates web automation framework', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
  end
end
