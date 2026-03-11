# frozen_string_literal: true

require 'json'
require 'rspec'
require_relative '../../lib/adopter/migration_plan'

RSpec.describe Adopter::MigrationPlan do
  let(:converted_page) do
    Adopter::ConvertedFile.new(
      output_path: 'my_project/page_objects/pages/login.rb',
      content: 'class Login < Page; end',
      source_file: 'pages/login_page.rb',
      conversion_notes: 'Converted from capybara to selenium'
    )
  end

  let(:plan) do
    described_class.new(
      source_path: '/source',
      output_path: '/output',
      target_automation: 'selenium',
      target_framework: 'rspec',
      ci_platform: 'github',
      skeleton_structure: { automation: 'selenium', framework: 'rspec', name: '/output' },
      converted_pages: [converted_page],
      converted_tests: [],
      gemfile_additions: %w[faker httparty],
      config_overrides: { browser: 'chrome', url: 'https://example.com' },
      warnings: ['Complex matcher needs review'],
      manual_actions: []
    )
  end

  describe '#to_h' do
    it 'serializes all fields' do
      hash = plan.to_h
      expect(hash[:source_path]).to eq('/source')
      expect(hash[:output_path]).to eq('/output')
      expect(hash[:target_automation]).to eq('selenium')
      expect(hash[:target_framework]).to eq('rspec')
      expect(hash[:converted_pages].length).to eq(1)
      expect(hash[:gemfile_additions]).to eq(%w[faker httparty])
      expect(hash[:config_overrides]).to eq(browser: 'chrome', url: 'https://example.com')
    end

    it 'serializes converted files as hashes' do
      page_hash = plan.to_h[:converted_pages].first
      expect(page_hash[:output_path]).to eq('my_project/page_objects/pages/login.rb')
      expect(page_hash[:source_file]).to eq('pages/login_page.rb')
    end
  end

  describe '#to_json' do
    it 'produces valid JSON' do
      parsed = JSON.parse(plan.to_json)
      expect(parsed['source_path']).to eq('/source')
      expect(parsed['converted_pages'].length).to eq(1)
    end
  end

  describe '#summary' do
    it 'returns counts' do
      expect(plan.summary).to eq(
        pages: 1,
        tests: 0,
        features: 0,
        steps: 0,
        custom_gems: 2,
        warnings: 1,
        manual_actions: 0
      )
    end
  end

  describe 'defaults' do
    it 'initializes with empty arrays and hashes' do
      empty_plan = described_class.new
      expect(empty_plan.converted_pages).to eq([])
      expect(empty_plan.converted_tests).to eq([])
      expect(empty_plan.gemfile_additions).to eq([])
      expect(empty_plan.config_overrides).to eq({})
      expect(empty_plan.warnings).to eq([])
    end
  end
end

RSpec.describe Adopter::ConvertedFile do
  it 'stores file conversion data' do
    file = described_class.new(
      output_path: 'project/spec/login_spec.rb',
      content: 'describe "Login" do; end',
      source_file: 'spec/login_spec.rb',
      conversion_notes: 'Restructured'
    )
    expect(file.output_path).to eq('project/spec/login_spec.rb')
    expect(file.content).to eq('describe "Login" do; end')
  end

  it 'serializes to hash' do
    file = described_class.new(
      output_path: 'out.rb',
      content: 'code',
      source_file: 'in.rb',
      conversion_notes: 'notes'
    )
    expect(file.to_h).to eq(
      output_path: 'out.rb',
      content: 'code',
      source_file: 'in.rb',
      conversion_notes: 'notes'
    )
  end
end
