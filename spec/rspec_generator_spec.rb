# frozen_string_literal: true

require_relative '../lib/generators/rspec_generator'
require_relative 'spec_helper'

describe RspecGenerator do
  frameworks = @frameworks
  automation_types = @automation_types

  shared_examples 'creates rspec files' do |name|
    it 'creates a spec file' do
      expect(File).to exist("#{name}/spec/login_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{name}/spec/base_spec.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates common files', "#{frameworks.last}_#{automation_types[2]}"
  end

  context 'with rspec and watir' do
    include_examples 'creates common files', "#{frameworks.last}_#{automation_types.last}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common files', "#{frameworks.last}_#{automation_types.first}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common files', "#{frameworks.last}_#{automation_types[1]}"
  end
end
