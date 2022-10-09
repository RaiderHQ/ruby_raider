# frozen_string_literal: true

require_relative '../lib/generators/common_generator'
require_relative 'spec_helper'

describe CommonGenerator do
  shared_examples 'creates common files' do |name|
    it 'creates a config file' do
      expect(File).to exist("#{name}/config/config.yml")
    end

    it 'creates a rake file' do
      expect(File).to exist("#{name}/Rakefile")
    end

    it 'creates a readMe file' do
      expect(File).to exist("#{name}/Readme.md")
    end

    it 'creates a gemfile file' do
      expect(File).to exist("#{name}/Gemfile")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.last}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES.first}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates common files', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[1]}"
  end
end
