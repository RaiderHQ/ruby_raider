# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'flow_project'

# `raider flow run` and `raider flow list` against a project with its own Gemfile, from another folder.
RSpec.describe 'raider flow run and list' do
  raider = File.expand_path('../../../bin/raider', __dir__)

  flows = {
    'ok' => <<~RUBY,
      require_relative 'flow_helper'

      RSpec.describe 'ok' do
        it('runs every step') { puts "who=\#{flow_input('who', 'nobody')} headless=\#{ENV.fetch('HEADLESS', 'unset')}" }
      end
    RUBY
    'broken' => <<~RUBY
      require_relative 'flow_helper'

      RSpec.describe 'broken' do
        it 'downloads the report' do
          raise 'no such element'
        end
      end
    RUBY
  }

  # Built once: bundling the project is the slow part
  dir = nil

  before(:context) do # rubocop:disable RSpec/BeforeAfterAll
    dir = File.realpath(Dir.mktmpdir('flow-command'))
    FlowProject.build(dir, flows)
    File.write(File.join(dir, 'Gemfile'), "source 'https://rubygems.org'\ngem 'rspec'\n")
    _out, err, status = Bundler.with_unbundled_env do
      Open3.capture3('bundle', 'install', '--prefer-local', '--quiet', chdir: dir)
    end
    raise "bundle install failed: #{err}" unless status.success?
  end

  after(:context) { FileUtils.rm_rf(dir) } # rubocop:disable RSpec/BeforeAfterAll

  define_method(:raider_flow) do |*args|
    out, err, status = Open3.capture3(RbConfig.ruby, raider, 'flow', *args, '--project', dir, chdir: Dir.tmpdir)
    [out, err, status.exitstatus]
  end

  it 'runs a completed flow, passing inputs and headless through, and exits 0' do
    out, _err, code = raider_flow('run', 'ok', '--input', 'who=ada')

    expect(code).to eq(0)
    expect(out).to include('who=ada headless=true', 'Flow ok completed in ')
    expect(out).to match(%r{^Results: flow-results/ok/\d{8}T\d{6}Z(-\d+)?$})
  end

  it 'exits 1 and names the failed line' do
    out, _err, code = raider_flow('run', 'broken')

    expect(code).to eq(1)
    expect(out).to include('Flow broken failed at line 5 (downloads the report)')
  end

  it 'exits 2 for a flow that does not exist' do
    _out, err, code = raider_flow('run', 'missing')

    expect(code).to eq(2)
    expect(err).to include('No flow missing: flows/missing_flow.rb not found')
  end

  it 'lists every flow with its last result as JSON for the desktop' do
    raider_flow('run', 'ok')
    out, _err, code = raider_flow('list', '--json')
    listed = JSON.parse(out)

    expect(code).to eq(0)
    expect(listed.map { |flow| flow['name'] }).to eq(%w[broken ok])
    expect(listed.last).to include('file' => 'flows/ok_flow.rb')
    expect(listed.last['last'].keys).to eq(%w[status finished_at failed_step results_dir])
    expect(listed.last['last']['status']).to eq('completed')
  end

  it 'lists flows as text' do
    raider_flow('run', 'ok')
    out, = raider_flow('list')

    expect(out).to match(/^ok\s+completed\s+\d{4}-\d\d-\d\dT/)
  end
end
