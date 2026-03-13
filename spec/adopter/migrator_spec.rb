# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/adopter/migration_plan'
require_relative '../../lib/adopter/migrator'

RSpec.describe Adopter::Migrator do
  let(:output_dir) { 'tmp_migrator_test' }

  after { FileUtils.rm_rf(output_dir) }

  describe '#execute' do
    context 'with skeleton generation' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          ci_platform: 'github',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir,
            ci_platform: 'github'
          }
        )
      end

      it 'generates a raider project skeleton' do
        described_class.new(plan).execute

        expect(File).to exist("#{output_dir}/Gemfile")
        expect(File).to exist("#{output_dir}/Rakefile")
        expect(File).to exist("#{output_dir}/page_objects/pages")
        expect(File).to exist("#{output_dir}/spec")
      end
    end

    context 'writing converted pages' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          },
          converted_pages: [
            Adopter::ConvertedFile.new(
              output_path: "#{output_dir}/page_objects/pages/login.rb",
              content: "# frozen_string_literal: true\n\nclass LoginPage < Page\nend\n",
              source_file: 'pages/login_page.rb',
              conversion_notes: 'Restructured'
            )
          ]
        )
      end

      it 'writes converted page files over the skeleton' do
        results = described_class.new(plan).execute

        expect(results[:pages]).to eq(1)
        content = File.read("#{output_dir}/page_objects/pages/login.rb")
        expect(content).to include('class LoginPage < Page')
      end
    end

    context 'writing converted tests' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          },
          converted_tests: [
            Adopter::ConvertedFile.new(
              output_path: "#{output_dir}/spec/login_spec.rb",
              content: "# frozen_string_literal: true\n\ndescribe 'Login' do\nend\n",
              source_file: 'spec/login_spec.rb',
              conversion_notes: 'Restructured'
            )
          ]
        )
      end

      it 'writes converted test files' do
        results = described_class.new(plan).execute

        expect(results[:tests]).to eq(1)
        content = File.read("#{output_dir}/spec/login_spec.rb")
        expect(content).to include("describe 'Login'")
      end
    end

    context 'writing cucumber features and steps' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'cucumber',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'cucumber',
            name: output_dir
          },
          converted_features: [
            Adopter::ConvertedFile.new(
              output_path: "#{output_dir}/features/login.feature",
              content: "Feature: Login\n  Scenario: Valid login\n",
              source_file: 'features/login.feature',
              conversion_notes: 'Copied as-is'
            )
          ],
          converted_steps: [
            Adopter::ConvertedFile.new(
              output_path: "#{output_dir}/features/step_definitions/login_steps.rb",
              content: "Given('I am on the login page') do\nend\n",
              source_file: 'features/step_definitions/login_steps.rb',
              conversion_notes: 'Updated page references'
            )
          ]
        )
      end

      it 'writes feature and step files' do
        results = described_class.new(plan).execute

        expect(results[:features]).to eq(1)
        expect(results[:steps]).to eq(1)
        expect(File).to exist("#{output_dir}/features/login.feature")
        expect(File).to exist("#{output_dir}/features/step_definitions/login_steps.rb")
      end
    end

    context 'merging custom gems into Gemfile' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          },
          gemfile_additions: %w[faker httparty]
        )
      end

      it 'appends custom gems to the generated Gemfile' do
        described_class.new(plan).execute

        gemfile = File.read("#{output_dir}/Gemfile")
        expect(gemfile).to include("gem 'faker'")
        expect(gemfile).to include("gem 'httparty'")
        expect(gemfile).to include('# Gems from source project')
      end

      it 'does not duplicate gems already in the Gemfile' do
        described_class.new(plan).execute

        # Selenium Gemfile already has 'rspec' — adding it again should be skipped
        plan2 = Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          },
          gemfile_additions: %w[faker new_gem]
        )
        described_class.new(plan2).execute

        gemfile = File.read("#{output_dir}/Gemfile")
        expect(gemfile.scan("gem 'faker'").length).to eq(1)
        expect(gemfile).to include("gem 'new_gem'")
      end
    end

    context 'applying config overrides' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          },
          config_overrides: { browser: 'firefox', url: 'https://example.com' }
        )
      end

      it 'updates config.yml with overridden values' do
        described_class.new(plan).execute

        config = YAML.safe_load(File.read("#{output_dir}/config/config.yml"), permitted_classes: [Symbol])
        expect(config['browser']).to eq('firefox')
        expect(config['url']).to eq('https://example.com')
      end
    end

    context 'error handling' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          },
          converted_pages: [
            Adopter::ConvertedFile.new(
              output_path: '/dev/null/impossible/path/file.rb',
              content: 'content',
              source_file: 'pages/bad.rb',
              conversion_notes: 'Will fail'
            )
          ]
        )
      end

      it 'captures write errors without stopping execution' do
        results = described_class.new(plan).execute

        expect(results[:errors]).not_to be_empty
        expect(results[:errors].first).to include('Failed to write')
      end
    end

    context 'results tracking' do
      let(:plan) do
        Adopter::MigrationPlan.new(
          source_path: 'dummy_source',
          output_path: output_dir,
          target_automation: 'selenium',
          target_framework: 'rspec',
          skeleton_structure: {
            automation: 'selenium',
            framework: 'rspec',
            name: output_dir
          }
        )
      end

      it 'returns zero counts when no files to convert' do
        results = described_class.new(plan).execute

        expect(results[:pages]).to eq(0)
        expect(results[:tests]).to eq(0)
        expect(results[:features]).to eq(0)
        expect(results[:steps]).to eq(0)
        expect(results[:errors]).to be_empty
      end
    end
  end
end
