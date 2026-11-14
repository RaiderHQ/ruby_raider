# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'yaml'
require_relative 'content_helper'
require_relative '../../../lib/ruby_raider/ffmpeg'

describe 'CI pipeline content' do
  shared_examples 'valid github pipeline' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'is valid YAML' do
      expect { YAML.safe_load(pipeline) }.not_to raise_error
    end

    it 'has name' do
      expect(pipeline).to match(/^name:/)
    end

    it 'has jobs section' do
      expect(pipeline).to include('jobs:')
    end

    it 'sets up Ruby' do
      expect(pipeline).to include('ruby')
    end

    it 'installs dependencies' do
      expect(pipeline).to include('bundler-cache: true').or include('bundle install')
    end
  end

  shared_examples 'github rspec pipeline' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'runs rspec' do
      expect(pipeline).to include('rspec')
    end
  end

  shared_examples 'github triggers' do |project_name, file|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:triggers) { YAML.safe_load(pipeline)[true] }

    it 'triggers on push to main and master' do
      expect(triggers['push']['branches']).to include('main', 'master')
    end

    it 'triggers on pull_request' do
      expect(triggers).to have_key('pull_request')
    end

    it 'triggers on workflow_dispatch' do
      expect(triggers).to have_key('workflow_dispatch')
    end
  end

  shared_examples 'github raider wiring' do |project_name, file, runner = 'rspec'|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:steps) { YAML.safe_load(pipeline)['jobs'].values.flat_map { |job| job['steps'] } }

    let(:test_steps) do
      steps.select { |step| step['run'].to_s.include?(runner) || step['with'].to_h['script'].to_s.include?(runner) }
    end

    it 'passes Raider settings to every test step' do
      expect(test_steps).not_to be_empty
      test_steps.each do |step|
        expect(step['env']).to include('RAIDER_TOKEN' => '${{ secrets.RAIDER_TOKEN }}',
                                       'RAIDER_ENDPOINT' => '${{ vars.RAIDER_ENDPOINT }}',
                                       'RAIDER_QUARANTINE' => '1')
      end
    end

    it 'runs every test command through raider-reporter exec' do
      expect(test_steps).not_to be_empty
      test_steps.each do |step|
        command = step['run'] || step['with']['script']
        wrapped = command.scan(/raider-reporter exec -- bundle exec #{runner}\b/).size
        expect(wrapped).to be_positive
        expect(command.scan(/bundle exec #{runner}\b/).size).to eq(wrapped)
      end
    end

    it 'uploads raider-results as an artifact even on failure in every job' do
      uploads = steps.select { |step| step['uses'] == 'actions/upload-artifact@v4' }
      expect(uploads.size).to eq(YAML.safe_load(pipeline)['jobs'].except('raider-comment', 'raider-gate').size)
      uploads.each do |upload|
        expect(upload['with']['path']).to eq('raider-results/')
        expect(upload['if']).to eq('always()')
      end
    end
  end

  shared_examples 'github raider-comment job' do |project_name, file, test_jobs|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:jobs) { YAML.safe_load(pipeline)['jobs'] }
    let(:job) { jobs['raider-comment'] }

    it 'is a valid workflow with exactly the expected jobs' do
      expect(jobs.keys).to match_array(test_jobs + %w[raider-comment raider-gate])
    end

    it 'needs every test job and the gate job, so the comment carries the final gate line' do
      expect(job['needs']).to match_array(test_jobs + %w[raider-gate])
    end

    it 'runs always, on pull requests only, so a skipped or failed gate job does not skip it' do
      expect(job['if']).to eq("always() && github.event_name == 'pull_request'")
      expect(job['if']).to start_with('always()')
      expect(job['runs-on']).to eq('ubuntu-latest')
    end

    it 'has the least permissions required' do
      expect(job['permissions']).to eq('contents' => 'read', 'pull-requests' => 'write', 'statuses' => 'write')
    end

    it 'checks out, sets up the same Ruby as the test jobs and comments' do
      steps = job['steps']
      expect(steps[0]).to eq('uses' => 'actions/checkout@v4')
      expect(steps[1]['uses']).to eq('ruby/setup-ruby@v1')
      test_ruby = jobs.values_at(*test_jobs).flat_map { |j| j['steps'] }
                      .find { |step| step['uses'] == 'ruby/setup-ruby@v1' }['with']['ruby-version']
      expect(steps[1]['with']).to eq('ruby-version' => test_ruby, 'bundler-cache' => true)
      expect(steps[2]).to eq('name' => 'Comment Raider results on the pull request',
                             'run' => 'bundle exec raider-reporter comment',
                             'env' => { 'RAIDER_TOKEN' => '${{ secrets.RAIDER_TOKEN }}',
                                        'RAIDER_ENDPOINT' => '${{ vars.RAIDER_ENDPOINT }}',
                                        'GITHUB_TOKEN' => '${{ secrets.GITHUB_TOKEN }}' })
      expect(steps.size).to eq(3)
    end
  end

  shared_examples 'github without allure steps' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    it 'has no Allure report or gh-pages steps' do
      expect(pipeline).not_to match(/allure|gh-pages/i)
    end

    it 'still uploads raider-results' do
      expect(pipeline).to include('name: raider-results', 'path: raider-results/')
    end
  end

  shared_examples 'github raider-gate job' do |project_name, file, test_jobs|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:jobs) { YAML.safe_load(pipeline)['jobs'] }
    let(:gate_job) { jobs['raider-gate'] }

    it 'needs every test job and runs always when RAIDER_GATE is 1, on push and pull requests' do
      expect(gate_job['needs']).to match_array(test_jobs)
      expect(gate_job['if']).to eq("always() && vars.RAIDER_GATE == '1'")
      expect(gate_job['runs-on']).to eq('ubuntu-latest')
    end

    it 'can read the code and write statuses only' do
      expect(gate_job['permissions']).to eq('contents' => 'read', 'statuses' => 'write')
    end

    it 'checks out, sets up the same Ruby as the test jobs and runs the gate' do
      steps = gate_job['steps']
      expect(steps[0]).to eq('uses' => 'actions/checkout@v4')
      test_ruby = jobs.values_at(*test_jobs).flat_map { |j| j['steps'] }
                      .find { |step| step['uses'] == 'ruby/setup-ruby@v1' }['with']['ruby-version']
      expect(steps[1]).to eq('uses' => 'ruby/setup-ruby@v1', 'with' => { 'ruby-version' => test_ruby, 'bundler-cache' => true })
      expect(steps[2]).to eq('name' => 'Wait for the Raider quality gate',
                             'run' => 'bundle exec raider-reporter gate',
                             'env' => { 'RAIDER_TOKEN' => '${{ secrets.RAIDER_TOKEN }}',
                                        'RAIDER_ENDPOINT' => '${{ vars.RAIDER_ENDPOINT }}',
                                        'GITHUB_TOKEN' => '${{ secrets.GITHUB_TOKEN }}' })
      expect(steps.size).to eq(3)
    end
  end

  shared_examples 'github appium shards' do |project_name, runner, shards|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/appium_pipeline.yml') }

    let(:jobs) { YAML.safe_load(pipeline)['jobs'] }

    def test_step(job, runner)
      job['steps'].find { |step| step['run'].to_s.include?(runner) || step['with'].to_h['script'].to_s.include?(runner) }
    end

    if shards
      it 'gives each platform job its own shard of two, so the gate waits for both' do
        shards.each do |job_name, index|
          expect(test_step(jobs[job_name], runner)['env'])
            .to include('RAIDER_SHARD_INDEX' => index, 'RAIDER_SHARD_TOTAL' => '2')
        end
      end
    else
      it 'sets no shard env for a single platform' do
        jobs.except('raider-comment', 'raider-gate').each_value do |job|
          expect(test_step(job, runner)['env'].keys).not_to include('RAIDER_SHARD_INDEX', 'RAIDER_SHARD_TOTAL')
        end
      end
    end
  end

  shared_examples 'github ffmpeg cache' do |project_name, file, test_jobs, runner = 'rspec'|
    subject(:pipeline) { read_generated(project_name, ".github/workflows/#{file}") }

    let(:jobs) { YAML.safe_load(pipeline)['jobs'] }

    test_jobs.each do |job_name|
      it "caches ~/.cache/raider keyed on the ffmpeg version and Gemfile.lock, then installs ffmpeg, before the tests in #{job_name}" do
        steps = jobs[job_name]['steps']
        cache = steps.index { |step| step['uses'] == 'actions/cache@v4' }
        install = steps.index { |step| step['run'] == 'bundle exec raider u video install' }
        tests = steps.index do |step|
          step['run'].to_s.include?(runner) || step['with'].to_h['script'].to_s.include?(runner)
        end
        expect([cache, install, tests]).to all(be_an(Integer))
        expect(cache).to be < install
        expect(install).to be < tests
        expect(steps[cache]['with']).to eq(
          'path' => '~/.cache/raider',
          'key' => "raider-ffmpeg-#{RubyRaider::Ffmpeg::MANIFEST[:version]}-${{ runner.os }}-${{ hashFiles('**/Gemfile.lock') }}"
        )
      end

      it "keeps the ffmpeg install step from failing #{job_name}, since video is optional" do
        install = jobs[job_name]['steps'].find { |step| step['run'] == 'bundle exec raider u video install' }
        expect(install['continue-on-error']).to be(true)
      end
    end

    it 'adds no cache or install step to the comment and gate jobs' do
      jobs.slice('raider-comment', 'raider-gate').each_value do |job|
        expect(job['steps'].map { |step| step['run'] || step['uses'] })
          .not_to include('actions/cache@v4', 'bundle exec raider u video install')
      end
    end
  end

  shared_examples 'github dispatch inputs' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    let(:inputs) { YAML.safe_load(pipeline)[true]['workflow_dispatch']['inputs'] }
    let(:test_step) { YAML.safe_load(pipeline)['jobs']['build']['steps'].find { |step| step['name'] == 'Run tests' } }

    it 'defaults the browser input to chrome, so a dispatch may leave it out' do
      expect(inputs['browser']).to include('type' => 'choice', 'required' => false, 'default' => 'chrome',
                                           'options' => ['chrome'])
    end

    it 'takes an optional tags string that defaults to blank' do
      expect(inputs['tags']).to include('type' => 'string', 'required' => false, 'default' => '')
      expect(inputs.keys).to contain_exactly('browser', 'tags')
    end

    it 'passes tags to the test step only through env, never pasted into the script' do
      expect(test_step['env']).to include('TAGS' => '${{ inputs.tags }}')
      expect(test_step['shell']).to eq('bash')
      expect(test_step['run']).not_to include('${{')
    end
  end

  # Runs the rendered Run tests script with a stub `bundle` that records its arguments.
  shared_examples 'github tags script' do |project_name|
    subject(:pipeline) { read_generated(project_name, '.github/workflows/test_pipeline.yml') }

    let(:script) { YAML.safe_load(pipeline)['jobs']['build']['steps'].find { |step| step['name'] == 'Run tests' }['run'] }
    let(:default_argv) { %w[exec raider-reporter exec -- bundle exec rspec spec --format documentation] }

    def run_script(script, tags)
      Dir.mktmpdir do |dir|
        stub = File.join(dir, 'bundle')
        File.write(stub, "#!/bin/sh\nfor arg in \"$@\"; do printf '%s\\n' \"$arg\"; done > \"#{dir}/argv\"\n")
        File.chmod(0o755, stub)
        env = { 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }
        env['TAGS'] = tags # nil unsets an inherited TAGS
        output, status = Open3.capture2e(env, 'bash', '--noprofile', '--norc', '-eo', 'pipefail', '-c', script, chdir: dir)
        argv = File.exist?("#{dir}/argv") ? File.read("#{dir}/argv").split("\n") : nil
        { output:, status: status.exitstatus, argv:, pwned: File.exist?(File.join(dir, 'pwned')) }
      end
    end

    [nil, '', '  ', ' , ,'].each do |tags|
      it "runs exactly today's command when tags is #{tags.inspect}" do
        expect(run_script(script, tags)).to include(status: 0, argv: default_argv, pwned: false)
      end
    end

    {
      'smoke' => %w[--tag smoke],
      '@smoke' => %w[--tag @smoke],
      'smoke,fast' => %w[--tag smoke --tag fast],
      ' smoke  fast, ' => %w[--tag smoke --tag fast],
      '~slow' => %w[--tag ~slow],
      '!slow' => %w[--tag ~slow],
      '~@slow, type:api' => %w[--tag ~@slow --tag type:api],
      'priority:1.5' => %w[--tag priority:1.5],
      'kind::api' => %w[--tag kind::api]
    }.each do |tags, expected|
      it "passes #{tags.inspect} to rspec as #{expected.join(' ')}" do
        expect(run_script(script, tags)).to include(status: 0, argv: default_argv + expected)
      end
    end

    ['$(touch pwned)', '`id`', 'a;b', 'smoke && id', '*', "'x'", '"x"', '-r x', '--require x', "smoke\nid",
     "smoke\tfast", 'a!b', '~', '@', 'a:', 'a:b:c', ':a', 'a|b', 'a/b', 'x' * 201].each do |tags|
      it "refuses #{tags.inspect} before rspec starts" do
        result = run_script(script, tags)
        expect(result).to include(status: 2, argv: nil, pwned: false)
        expect(result[:output]).to include('::error::')
      end
    end
  end

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'github dispatch inputs', name
    include_examples 'github tags script', name
    include_examples 'github ffmpeg cache', name, 'test_pipeline.yml', %w[build]
    include_examples 'valid github pipeline', name
    include_examples 'github rspec pipeline', name
    include_examples 'github triggers', name, 'test_pipeline.yml'
    include_examples 'github raider wiring', name, 'test_pipeline.yml'
    include_examples 'github raider-comment job', name, 'test_pipeline.yml', %w[build]
    include_examples 'github raider-gate job', name, 'test_pipeline.yml', %w[build]
    include_examples 'github without allure steps', name
  end

  appium_jobs = { 'android' => %w[android-tests], 'ios' => %w[ios-tests],
                  'cross_platform' => %w[ios-tests android-tests] }

  appium_shards = { 'cross_platform' => { 'ios-tests' => '1', 'android-tests' => '2' } }

  appium_jobs.each do |automation, test_jobs|
    context "with rspec and #{automation}" do
      name = "#{FrameworkIndex::RSPEC}_#{automation}"
      include_examples 'github appium shards', name, 'rspec', appium_shards[automation]
      include_examples 'github ffmpeg cache', name, 'appium_pipeline.yml', test_jobs
      include_examples 'github raider-comment job', name, 'appium_pipeline.yml', test_jobs
      include_examples 'github raider-gate job', name, 'appium_pipeline.yml', test_jobs
      include_examples 'github triggers', name, 'appium_pipeline.yml'
      include_examples 'github raider wiring', name, 'appium_pipeline.yml'
    end
  end

  context 'with the saved login state' do
    workflows = FRAMEWORKS.product(%w[selenium]).map { |f, a| ["#{f}_#{a}", 'test_pipeline.yml'] } +
                FRAMEWORKS.product(%w[android ios cross_platform]).map { |f, a| ["#{f}_#{a}", 'appium_pipeline.yml'] }

    workflows.each do |name, file|
      it "keeps .raider/auth out of #{name}/#{file}" do
        expect(read_generated(name, ".github/workflows/#{file}")).not_to include('.raider')
      end
    end
  end
end
