# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'yaml'
require_relative '../../../lib/generators/infrastructure/azure_generator'
require_relative '../spec_helper'

describe AzureGenerator do
  mobile_notice = "Azure Pipelines template for mobile projects is not available yet; see the README.\n"
  web = FRAMEWORKS.product(%w[selenium watir], [false, true])
  mobile = FRAMEWORKS.product(%w[ios android cross_platform])

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FileUtils.rm_rf(Dir.glob('azure_*'))
    FileUtils.rm_rf(Dir.glob('plain_*'))
    FileUtils.rm_rf(Dir.glob('ghci_*'))
  end

  web.each do |framework, automation, axe|
    context "with ci azure, #{framework}, #{automation}#{', axe' if axe}" do
      let(:name) { "azure_#{framework}_#{automation}#{'_axe' if axe}" }

      before do
        next if File.exist?(name)

        InvokeGenerators.generate_framework(automation:, framework:, name:, accessibility: axe, ci: 'azure')
      end

      it 'creates azure-pipelines.yml and no .github directory' do
        expect(File).to exist("#{name}/azure-pipelines.yml")
        expect(File).not_to exist("#{name}/.github")
      end

      it 'is parseable YAML' do
        expect { YAML.safe_load_file("#{name}/azure-pipelines.yml") }.not_to raise_error
      end
    end
  end

  mobile.each do |framework, automation|
    context "with ci azure, #{framework}, #{automation}" do
      let(:name) { "azure_#{framework}_#{automation}" }

      it 'generates no pipeline, no .github and prints the notice' do
        expect do
          InvokeGenerators.generate_framework(automation:, framework:, name:, ci: 'azure')
        end.to output(/#{Regexp.escape(mobile_notice)}/).to_stdout
        expect(File).not_to exist("#{name}/azure-pipelines.yml")
        expect(File).not_to exist("#{name}/.github")
      end
    end
  end

  context 'with the default ci and ci github' do
    it 'generates GitHub files and no azure-pipelines.yml' do
      InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'plain_default')
      InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'ghci_github', ci: 'github')
      %w[plain_default ghci_github].each do |name|
        expect(File).to exist("#{name}/.github/workflows/test_pipeline.yml")
        expect(File).not_to exist("#{name}/azure-pipelines.yml")
      end
    end
  end

  context 'with an invalid ci' do
    it 'raises a Thor::Error and generates nothing' do
      expect do
        InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'azure_bad', ci: 'gitlab')
      end.to raise_error(Thor::Error, 'ci must be github or azure')
      expect(File).not_to exist('azure_bad')
    end
  end

  context 'with raider new and ci:gitlab' do
    it 'prints the error, generates nothing and exits non-zero' do
      root = File.expand_path('../../..', __dir__)
      out, status = Open3.capture2e('ruby', "#{root}/bin/raider", 'new', 'azure_cli_bad', '-p', 'framework:rspec',
                                    'automation:selenium', 'ci:gitlab')
      expect(status.exitstatus).not_to eq(0)
      expect(out).to include('ci must be github or azure')
      expect(File).not_to exist('azure_cli_bad')
    end
  end

  context 'with a project named azure' do
    after { FileUtils.rm_rf(%w[azure azure_named_ci]) }

    it 'generates the GitHub workflow with the default ci' do
      InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'azure')
      expect(File).to exist('azure/.github/workflows')
      expect(File).not_to exist('azure/azure-pipelines.yml')
    end

    it 'generates the Azure pipeline with ci azure' do
      InvokeGenerators.generate_framework(automation: 'selenium', framework: 'rspec', name: 'azure', ci: 'azure')
      expect(File).to exist('azure/azure-pipelines.yml')
      expect(File).not_to exist('azure/.github')
    end
  end
end
