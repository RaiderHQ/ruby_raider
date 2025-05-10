# frozen_string_literal: true

require_relative '../../../lib/generators/infrastructure/gitlab_generator'
require_relative '../spec_helper'

describe GitlabGenerator do
  shared_examples 'selects gitlab as an infrastructure option' do |name|
    it 'creates a gitlab infrastructure file' do
      expect(File).to exist("#{name}/gitlab-ci.yml")
    end
  end

  shared_examples 'does not select any infrastructure option' do |name|
    it 'does not create a gitlab infrastructure file' do
      expect(File).not_to exist("#{name}/gitlab-ci.yml")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'selects gitlab as an infrastructure option', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}_#{CI_PLATFORMS[2]}"
    include_examples 'does not select any infrastructure option', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'selects gitlab as an infrastructure option', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}_#{CI_PLATFORMS[2]}"
    include_examples 'does not select any infrastructure option', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with cucumber and selenium' do
    include_examples 'selects gitlab as an infrastructure option', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}_#{CI_PLATFORMS[2]}"
    include_examples 'does not select any infrastructure option', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'selects gitlab as an infrastructure option', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}_#{CI_PLATFORMS[2]}"
    include_examples 'does not select any infrastructure option', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
  end
end
