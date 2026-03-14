# frozen_string_literal: true

require_relative 'content_helper'

describe 'Gemfile content' do
  shared_examples 'contains common gems' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes rubygems source' do
      expect(gemfile).to include("source 'https://rubygems.org'")
    end

    it 'includes rake' do
      expect(gemfile).to include("gem 'rake'")
    end

    it 'includes reek' do
      expect(gemfile).to include("gem 'reek'")
    end

    it 'includes rubocop' do
      expect(gemfile).to include("gem 'rubocop'")
    end

    it 'includes activesupport' do
      expect(gemfile).to include("gem 'activesupport'")
    end
  end

  shared_examples 'contains rspec gems' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes rspec' do
      expect(gemfile).to include("gem 'rspec'")
    end

    it 'includes allure-rspec' do
      expect(gemfile).to include("gem 'allure-rspec'")
    end

    it 'includes rubocop-rspec' do
      expect(gemfile).to include("gem 'rubocop-rspec'")
    end

    it 'does not include cucumber' do
      expect(gemfile).not_to include("gem 'cucumber'")
    end

    it 'does not include minitest' do
      expect(gemfile).not_to include("gem 'minitest'\n")
    end
  end

  shared_examples 'contains cucumber gems' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes cucumber' do
      expect(gemfile).to include("gem 'cucumber'")
    end

    it 'includes allure-cucumber' do
      expect(gemfile).to include("gem 'allure-cucumber'")
    end

    it 'includes rspec as cucumber dependency' do
      expect(gemfile).to include("gem 'rspec'")
    end
  end

  shared_examples 'contains selenium gems' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes selenium-webdriver' do
      expect(gemfile).to include("gem 'selenium-webdriver'")
    end

    it 'does not include watir' do
      expect(gemfile).not_to include("gem 'watir'")
    end
  end

  shared_examples 'contains watir gems' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes watir' do
      expect(gemfile).to include("gem 'watir'")
    end

    it 'does not include selenium-webdriver' do
      expect(gemfile).not_to include("gem 'selenium-webdriver'")
    end
  end

  shared_examples 'contains debug gems' do |project_name|
    subject(:gemfile) { read_generated(project_name, 'Gemfile') }

    it 'includes debug gem' do
      expect(gemfile).to include("gem 'debug'")
    end

    it 'includes pry gem' do
      expect(gemfile).to include("gem 'pry'")
    end
  end

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'contains common gems', name
    include_examples 'contains rspec gems', name
    include_examples 'contains selenium gems', name
    include_examples 'contains debug gems', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'contains common gems', name
    include_examples 'contains rspec gems', name
    include_examples 'contains watir gems', name
    include_examples 'contains debug gems', name
  end

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'contains common gems', name
    include_examples 'contains cucumber gems', name
    include_examples 'contains selenium gems', name
    include_examples 'contains debug gems', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'contains common gems', name
    include_examples 'contains cucumber gems', name
    include_examples 'contains watir gems', name
    include_examples 'contains debug gems', name
  end

end
