# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'content_helper'

# UseRubyVersion@0 versionSpec '3.4' resolves against the hosted tool cache, which lists Ruby 3.4.x
# (3.2, 3.3, 3.4, 4.0): https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md
describe 'Azure Pipelines content' do
  combos = FRAMEWORKS.product(%w[selenium watir], [false, true])

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    combos.each do |framework, automation, axe|
      name = "azurec_#{framework}_#{automation}#{'_axe' if axe}"
      next if File.exist?(name)

      InvokeGenerators.generate_framework(automation:, framework:, name:, accessibility: axe, ci: 'azure')
    end
  end

  after(:all) { FileUtils.rm_rf(Dir.glob('azurec_*')) } # rubocop:disable RSpec/BeforeAfterAll

  combos.each do |framework, automation, axe|
    context "with #{framework}, #{automation}#{', axe' if axe}" do
      let(:name) { "azurec_#{framework}_#{automation}#{'_axe' if axe}" }
      let(:raw) { read_generated(name, 'azure-pipelines.yml') }
      let(:yml) { YAML.safe_load(raw) }
      let(:run_command) do
        if framework == 'cucumber'
          'bundle exec cucumber features/ --format pretty'
        else
          'bundle exec rspec spec/ --format documentation'
        end
      end

      it 'has a tests job with ruby, bundle install, run command and an always-published artifact' do
        tests = yml['jobs'][0]
        expect(tests['job']).to eq('tests')
        steps = tests['steps']
        expect(steps.first).to eq('task' => 'UseRubyVersion@0', 'inputs' => { 'versionSpec' => '3.4' })
        expect(steps.map { |s| s['script'] }).to include('bundle install', run_command)
        publish = steps.find { |s| s['task'] == 'PublishPipelineArtifact@1' }
        expect(publish['condition']).to eq('always()')
        expect(publish['inputs']).to eq(
          'targetPath' => 'raider-results',
          'artifact' => 'raider-results-$(System.JobPositionInPhase)-$(System.JobAttempt)'
        )
      end

      it 'passes exactly the Raider settings to the test step' do
        step = yml['jobs'][0]['steps'].find { |s| s['script'] == run_command }
        expect(step['env']).to eq('RAIDER_TOKEN' => '$(RAIDER_TOKEN)', 'RAIDER_ENDPOINT' => '$(RAIDER_ENDPOINT)')
        expect(yml['variables']['HEADLESS']).to eq('true')
      end

      it 'has a raider_comment job for pull requests' do
        comment = yml['jobs'][1]
        expect(comment['job']).to eq('raider_comment')
        expect(comment['dependsOn']).to eq('tests')
        expect(comment['condition']).to eq("and(always(), eq(variables['Build.Reason'], 'PullRequest'))")
        last = comment['steps'].last
        expect(last['script']).to eq('bundle exec raider-reporter comment')
        expect(last['env']).to include('SYSTEM_ACCESSTOKEN' => '$(System.AccessToken)')
      end

      it 'has triggers, pool and the self-hosted hint' do
        expect(yml['trigger']['branches']['include']).to include('main', 'master')
        expect(yml['pr']['branches']['include']).to include('*')
        expect(yml['pool']).to eq('vmImage' => 'ubuntu-latest')
        expect(raw).to include('# Self-hosted agent? Replace vmImage with: pool: { name: Default }')
      end

      it 'explains that Azure Repos ignores pr: directly above the pr block' do
        expect(raw).to include('# Azure Repos ignores pr: — add this pipeline as a Build validation branch policy ' \
                               "so pull request builds (and the Raider comment) run.\npr:")
      end

      it 'has no Allure' do
        expect(raw).not_to match(/allure/i)
      end

      it 'documents Azure Pipelines in the README and no GitHub Actions setup' do
        readme = read_generated(name, 'Readme.md')
        expect(readme).to include('## Azure Pipelines', 'RAIDER_TOKEN', 'Contribute to pull requests',
                                  'pool: { name: Default }', 'Build validation branch policy',
                                  'same stage')
        expect(readme).not_to match(/GitHub Actions/i)
      end
    end
  end

  context 'with a mobile project and ci azure' do
    let(:readme) { read_generated('azurec_mobile', 'Readme.md') }

    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      InvokeGenerators.generate_framework(automation: 'ios', framework: 'rspec', name: 'azurec_mobile', ci: 'azure')
    end

    it 'says the template is not available and does not mention azure-pipelines.yml' do
      expect(readme).to include('## CI', 'Azure Pipelines template for mobile projects is not available yet. ' \
                                         'Use GitHub Actions (`ci:github`)')
      expect(readme).not_to include('azure-pipelines.yml', '## Azure Pipelines')
    end
  end

  it 'does not generate azure-pipelines.yml for default projects' do
    expect(File).not_to exist("#{project('rspec', 'selenium')}/azure-pipelines.yml")
  end
end
