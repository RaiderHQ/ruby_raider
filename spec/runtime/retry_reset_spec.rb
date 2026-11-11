# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Real rspec-retry runs in a subprocess, no browser. The suite mimics a generated project: driver_helper
# memoises @driver, the after hook quits it, and a quit driver refuses every call like a dead session.
RSpec.describe 'Retrying a test with a fresh driver' do
  lib = File.expand_path('../../lib', __dir__)

  suite = <<~'RUBY'
    require 'json'
    require 'rspec'
    require 'rspec/retry' if ENV['RETRY'] == 'before'
    require 'ruby_raider/runtime/rspec'
    require 'rspec/retry' if ENV['RETRY'] == 'after'

    LOG = ENV.fetch('LOG')
    def log(entry) = File.open(LOG, 'a') { |file| file.puts(JSON.generate(entry)) }

    class FakeDriver
      def quit = @quit = true

      def title
        raise Errno::ECONNREFUSED, '127.0.0.1:9515' if @quit

        'ok'
      end
    end

    module DriverHelper
      def driver = @driver ||= FakeDriver.new
    end

    RSpec.configure do |config|
      config.include(DriverHelper)
      config.default_retry_count = ENV.fetch('RETRY_COUNT', 0).to_i if config.respond_to?(:default_retry_count=)
      # A project's own callback: one that resets the driver itself, or one that does not
      if ENV['OWN_CALLBACK']
        config.retry_callback = proc do
          log('callback' => 'project')
          @driver = nil if ENV['OWN_CALLBACK'] == 'resets'
        end
      end
      config.before(:each) { driver.title }
      config.after(:each) { driver.quit }
      config.after(:suite) do
        callback = config.retry_callback if config.respond_to?(:retry_callback)
        owner = { Raider::RetryReset::CALLBACK => 'ours', nil => 'none' }.fetch(callback, 'project')
        log('installed' => config.respond_to?(:retry_callback) ? owner : 'no rspec-retry')
      end
    end

    RSpec.describe 'Flaky' do
      it 'fails on its first try and passes on the next' do
        tries = File.readlines(LOG).count { |line| line.include?('"try"') } + 1
        log('try' => tries, 'driver' => driver.object_id)
        expect(tries).to eq(ENV.fetch('PASS_ON', '2').to_i)
      end
    end
  RUBY

  # The subprocess is a plain ruby, not bundle exec: it finds rspec and rspec-retry through the bundle env
  # (BUNDLE_GEMFILE, RUBYOPT=-rbundler/setup) it inherits from this rspec run.
  define_method(:run_suite) do |env|
    Dir.mktmpdir('raider-retry') do |dir|
      spec = File.join(dir, 'flaky_spec.rb')
      log = File.join(dir, 'log.jsonl')
      File.write(spec, suite)
      File.write(log, '')
      out, err, status = Open3.capture3(env.merge('LOG' => log, 'RSPEC_RETRY_RETRY_COUNT' => nil), RbConfig.ruby, '-I', lib,
                                        '-e', 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)', spec, chdir: dir)
      { status: status.exitstatus, output: out + err, log: File.readlines(log).map { |line| JSON.parse(line) } }
    end
  end

  define_method(:tries) { |result| result[:log].select { |entry| entry.key?('try') } }
  define_method(:installed) { |result| result[:log].find { |entry| entry.key?('installed') }&.fetch('installed') }

  %w[before after].each do |order|
    it "passes on the second try with a fresh driver when rspec/retry is required #{order} the runtime" do
      result = run_suite('RETRY' => order, 'RETRY_COUNT' => '2')
      expect([result[:status], tries(result).map { |entry| entry['try'] }]).to eq([0, [1, 2]]), result[:output]
      expect(tries(result).map { |entry| entry['driver'] }.uniq.size).to eq(2)
      expect(installed(result)).to eq('ours')
    end
  end

  it 'keeps a retry_callback the project set' do
    result = run_suite('RETRY' => 'before', 'RETRY_COUNT' => '2', 'OWN_CALLBACK' => 'resets')
    expect([result[:status], installed(result)]).to eq([0, 'project']), result[:output]
    expect(result[:log]).to include({ 'callback' => 'project' })
  end

  it 'a project callback that keeps the driver still fails on the quit session' do
    result = run_suite('RETRY' => 'before', 'RETRY_COUNT' => '2', 'OWN_CALLBACK' => 'keeps')
    expect([result[:status], installed(result), tries(result).size]).to eq([1, 'project', 1])
    expect(result[:output]).to include('Errno::ECONNREFUSED')
  end

  it 'changes nothing when no retry happens' do
    result = run_suite('RETRY' => 'before', 'RETRY_COUNT' => '2', 'PASS_ON' => '1')
    expect([result[:status], tries(result).size, installed(result)]).to eq([0, 1, 'ours']), result[:output]
  end

  it 'does nothing without rspec-retry' do
    result = run_suite('PASS_ON' => '1')
    expect([result[:status], installed(result)]).to eq([0, 'no rspec-retry']), result[:output]
  end
end
