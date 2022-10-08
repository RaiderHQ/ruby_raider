# frozen_string_literal: true

require_relative '../lib/generators/rspec_generator'
require_relative 'spec_helper'

describe RspecGenerator do
  frameworks = @frameworks
  automation_types = @automation_types

  context 'with selenium' do
    name = "#{frameworks.last}_#{automation_types[2]}"

    it 'creates a spec file' do
      expect(File).to exist("#{name}/spec/login_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{name}/spec/base_spec.rb")
    end
  end

  context 'with watir' do
    name = "#{frameworks.last}_#{automation_types.last}"

    it 'creates a spec file' do
      expect(File).to exist("#{name}/spec/login_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{name}/spec/base_spec.rb")
    end
  end

  context 'with ios appium' do
    name = "#{frameworks.last}_#{automation_types[1]}"

    it 'creates a spec file' do
      expect(File).to exist("#{name}/spec/pdp_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{name}/spec/base_spec.rb")
    end
  end

  context 'with android appium' do
    name = "#{frameworks.first}_#{automation_types[2]}"

    after(:all) do
      FileUtils.rm_rf(name)
    end

    it 'creates a spec file' do
      expect(File).to exist("#{name}/spec/pdp_page_spec.rb")
    end

    it 'creates the base spec file' do
      expect(File).to exist("#{name}/spec/base_spec.rb")
    end
  end
end
