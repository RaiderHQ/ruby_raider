# frozen_string_literal: true

require 'json'
require 'open3'
require 'stringio'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/run_wrapper'

# `raider schedule run` for real: a project with its own Gemfile (rspec, rspec-retry, raider_reporter 1.x)
# and a spec_helper wired like the generated one (retry count from RETRY_COUNT, raider_reporter formatter),
# run through the shipped spawner. No browser: the selections, retries, lock and counts are what is tested.
RSpec.describe 'raider schedule run against a real project', :slow do
  files = {
    'Gemfile' => <<~RUBY,
      source 'https://rubygems.org'

      gem 'raider_reporter', '~> 1.0'
      gem 'rspec'
      gem 'rspec-retry'
    RUBY
    '.rspec' => "--require spec_helper\n",
    'spec/spec_helper.rb' => <<~RUBY,
      require 'rspec'
      require 'rspec/retry'
      require 'raider_reporter/rspec'

      RSpec.configure do |config|
        config.verbose_retry = true
        config.display_try_failure_messages = true
        config.default_retry_count = ENV.fetch('RETRY_COUNT', 0).to_i
        config.add_formatter(RaiderReporter::RSpec::Formatter)
      end
    RUBY
    'spec/smoke_spec.rb' => <<~RUBY,
      RSpec.describe 'smoke', :smoke do
        it('opens') { expect(1).to eq(1) }
        it('closes') { expect(ENV['HEADLESS']).to eq('true') }
      end
    RUBY
    'spec/cart_spec.rb' => <<~RUBY,
      RSpec.describe 'cart' do
        it('adds') { expect(1).to eq(1) }
        it('pays') { expect(1).to eq(2) }
      end
    RUBY
    # Fails on its first try, passes on the next: only a retry makes it pass
    'spec/flaky_spec.rb' => <<~RUBY
      RSpec.describe 'flaky', :flaky do
        it 'passes on the second try' do
          marker = File.expand_path('../flaky.tried', __dir__)
          next if File.exist?(marker)

          File.write(marker, '')
          raise 'first try'
        end
      end
    RUBY
  }

  # rubocop:disable RSpec/InstanceVariable
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    @dir = File.realpath(Dir.mktmpdir('schedules-run-real'))
    files.each do |path, content|
      FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
      File.write(File.join(@dir, path), content)
    end
    installed = Bundler.with_unbundled_env do
      Open3.capture2e('bundle', 'install', '--local', '--quiet', chdir: @dir).last.success? ||
        Open3.capture2e('bundle', 'install', '--quiet', chdir: @dir).last.success?
    end
    raise 'bundle install of the fixture project failed' unless installed
  end

  after(:all) { FileUtils.rm_rf(@dir) } # rubocop:disable RSpec/BeforeAfterAll

  let(:dir) { @dir }
  # rubocop:enable RSpec/InstanceVariable
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:out) { StringIO.new }
  let(:notifier) { Class.new { def notify(*) = false }.new }
  let(:wrapper) { RubyRaider::Schedules::RunWrapper.new(project, out: out, err: StringIO.new, notifier: notifier) }

  before { FileUtils.rm_f(File.join(dir, 'flaky.tried')) }

  def schedule(name, selection: RubyRaider::Schedules::Selection.all, retries: 0)
    RubyRaider::Schedules::ScheduleStore.new(project).save(
      RubyRaider::Schedules::Schedule.build(project: project, name: name, every: 'day', at: '08:00', retries: retries,
                                            selection: selection, host_os: 'darwin')
    )
  end

  # rspec's own output goes to a file, not the spec run's terminal
  def run(name)
    saved = [$stdout.dup, $stderr.dup]
    File.open(File.join(dir, 'rspec.out'), 'w') do |file|
      $stdout.reopen(file)
      $stderr.reopen(file)
      wrapper.run(name)
    end
  ensure
    $stdout.reopen(saved[0])
    $stderr.reopen(saved[1])
  end

  def last_line(name) = JSON.parse(File.readlines(File.join(dir, ".raider/schedules/#{name}/runs.jsonl")).last)

  def tag(name) = RubyRaider::Schedules::Selection.new(kind: 'tag', tag: name)

  it 'runs all tests: failed, counted from raider-results/run.json, report copied' do
    schedule('all_tests')

    expect(run('all_tests')).to eq(1)
    expect(last_line('all_tests')).to include('status' => 'failed', 'counts' => { 'total' => 5, 'passed' => 3, 'failed' => 2, 'skipped' => 0 })
    expect(out.string).to eq("Schedule all_tests failed: 2 of 5 tests failed\n")
    expect(File.read(File.join(dir, '.raider/schedules/all_tests/last/run.json'))).to eq(File.read(File.join(dir, 'raider-results/run.json')))
  end

  it 'runs one tag, hidden: passed' do
    schedule('tag_smoke', selection: tag('smoke'))

    expect(run('tag_smoke')).to eq(0)
    expect(out.string).to eq("Schedule tag_smoke passed: 2 tests\n")
  end

  it 'runs the listed files' do
    schedule('selected_tests', selection: RubyRaider::Schedules::Selection.new(kind: 'files', files: %w[spec/cart_spec.rb]))

    expect(run('selected_tests')).to eq(1)
    expect(last_line('selected_tests')['counts']).to eq('total' => 2, 'passed' => 1, 'failed' => 1, 'skipped' => 0)
  end

  it 'retries a failing test through RETRY_COUNT, so a test that passes on its second try passes' do
    schedule('flaky_none', selection: tag('flaky'))
    schedule('flaky_once', selection: tag('flaky'), retries: 1)

    expect(run('flaky_none')).to eq(1)
    FileUtils.rm_f(File.join(dir, 'flaky.tried'))
    expect(run('flaky_once')).to eq(0)
    expect(last_line('flaky_once')['counts']).to eq('total' => 1, 'passed' => 1, 'failed' => 0, 'skipped' => 0)
  end

  it 'is busy while another run holds the lock: exit 3, nothing run, raider-results untouched' do
    schedule('tag_smoke', selection: tag('smoke'))
    run('tag_smoke')
    results = File.join(dir, 'raider-results')
    snapshot = -> { Dir.glob('**/*', base: results).sort.map { |path| [path, File.mtime(File.join(results, path)), File.size(File.join(results, path))] } }
    before = snapshot.call

    File.open(File.join(dir, '.raider/schedules/run.lock'), File::RDWR) do |held|
      held.flock(File::LOCK_EX)

      expect(run('tag_smoke')).to eq(3)
    end
    expect([last_line('tag_smoke')['status'], snapshot.call]).to eq(['busy', before])
  end

  it 'is a setup error when a listed file is gone: exit 2, nothing run' do
    File.write(File.join(dir, 'spec/gone_spec.rb'), "RSpec.describe('gone') { it('x') {} }\n")
    schedule('gone', selection: RubyRaider::Schedules::Selection.new(kind: 'files', files: %w[spec/gone_spec.rb]))
    File.delete(File.join(dir, 'spec/gone_spec.rb'))

    expect(run('gone')).to eq(2)
    expect(last_line('gone')['status']).to eq('setup_error')
    expect(out.string).to eq("Schedule gone could not start: spec/gone_spec.rb not found: remove the schedule or add it again\n")
  end
end
