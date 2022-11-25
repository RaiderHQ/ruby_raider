# frozen_string_literal: true

require_relative '../lib/generators/rspec_generator'
require_relative 'spec_helper'

describe RspecGenerator do
  shared_examples 'creates rspec files' do |project_name, file_name|
    it 'creates a spec file' do
      expect(File).to exist("#{project_name}/spec/#{file_name}_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{project_name}/spec/base_spec.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates rspec files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}", 'login'
  end

  context 'with rspec and watir' do
    include_examples 'creates rspec files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}", 'login'
  end

  context 'with rspec and appium android' do
    include_examples 'creates rspec files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.first}", 'pdp'
  end

  context 'with rspec and appium ios' do
    include_examples 'creates rspec files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[1]}", 'pdp'
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates rspec files', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES.last}", 'pdp'
  end
end
