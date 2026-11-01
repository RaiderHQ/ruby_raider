# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'stringio'
require 'tmpdir'
require 'yaml'
require 'zip'
require_relative '../../lib/generators/helper_generator'
require_relative '../integration/trace_format_checker'

# Renders the real trace_helper.tt for a Selenium project, loads it, and drives its
# Recorder the way WaitHelper's observer hook and the navigation listener do, with a
# driver double. The zips it writes are read back with rubyzip.
# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/ExpectOutput, RSpec/MultipleExpectations, RSpec/ExampleLength
describe 'Generated TraceHelper' do
  let(:template) { File.expand_path('../../lib/generators/templates/helpers/trace_helper.tt', __dir__) }
  let(:project_dir) { Dir.mktmpdir('trace-helper-project') }
  let(:trace_config) { { 'enabled' => true, 'max_steps' => 200, 'max_mb' => 20 } }
  let(:env) { {} }
  let(:png) { "\x89PNG\r\n\x1A\nfake-png".b }
  let(:html) { "<html><head><title>Login</title></head><body>#{'<p>row</p>' * 50}</body></html>" }
  let(:capabilities) { double('capabilities', browser_name: 'chrome', browser_version: '131.0.6778.85') }
  let(:window) { double('window', size: double('size', width: 1920, height: 1080)) }
  let(:driver) do
    double('driver', screenshot_as: png, page_source: html, current_url: 'https://example.test/login', title: 'Login',
                     capabilities: capabilities, manage: double('manage', window: window), execute_script: 2)
  end
  let(:wait_helper) do
    Module.new do
      class << self
        attr_accessor :observer
      end
    end
  end
  let(:stderr) { StringIO.new }
  let(:warnings) { stderr.string.lines.grep(/\[trace\]/) }
  let(:source) { { file: 'spec/login_page_spec.rb', line: 12 } }
  let(:failed_test) { { identifier: 'spec/login_page_spec.rb[1:1]', full_name: 'Login page logs in', status: 'failed', attempt: 2, error: nil } }

  def render_and_load
    generator = HelpersGenerator.new(%w[selenium rspec proj])
    rendered = ERB.new(File.read(template), trim_mode: '-').result(generator.instance_eval { binding })
    path = File.join(project_dir, 'trace_helper.rb')
    File.write(path, rendered)
    load path
  end

  def started_recorder(**lambdas)
    TraceHelper.recorder_for(driver, **lambdas).tap(&:start)
  end

  # What WaitHelper reports for one action.
  def act(recorder, action, selector, status: :passed, error: nil, label: nil, within: [])
    token = recorder.action_started(action: action, locator: { strategy: 'id', selector: selector }, within: within,
                                    source: source, label: label)
    recorder.action_finished(token, status: status, waited_ms: 95, retries: 1, error: error, element: nil)
  end

  def kept(recorder, test = failed_test)
    path = recorder.stop(keep: true, test: test)
    expect(TraceFormatChecker.problems(path)).to eq([])
    TraceFormatChecker.read(path).first
  end

  around do |example|
    original_stderr = $stderr
    $stderr = stderr
    FileUtils.mkdir_p(File.join(project_dir, 'config'))
    File.write(File.join(project_dir, 'config', 'config.yml'), { 'browser' => 'chrome', 'trace' => trace_config }.to_yaml)
    Dir.chdir(project_dir) { example.run }
  ensure
    $stderr = original_stderr
    Object.send(:remove_const, :TraceHelper) if defined?(TraceHelper)
    FileUtils.rm_rf(project_dir)
  end

  before do
    # Recorder tmpdirs land inside the project, which the around hook removes.
    stub_const('ENV', ENV.to_h.merge(env).merge('TMPDIR' => File.join(project_dir, 'tmp')).compact)
    FileUtils.mkdir_p(File.join(project_dir, 'tmp'))
    stub_const('WaitHelper', wait_helper)
    render_and_load
  end

  it 'writes a zip whose trace.json has format raider-trace, version 1 and the spec §1 top-level keys' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    trace = kept(recorder)

    expect(trace.keys).to eq(%w[format version producer test browser viewport device_pixel_ratio started_at finished_at
                                capabilities truncated steps network console])
    expect(trace).to include('format' => 'raider-trace', 'version' => 1,
                             'producer' => { 'name' => 'ruby_raider', 'version' => File.read(File.expand_path('../../lib/version', __dir__)).strip },
                             'test' => { 'identifier' => 'spec/login_page_spec.rb[1:1]', 'full_name' => 'Login page logs in',
                                         'status' => 'failed', 'attempt' => 2 },
                             'browser' => { 'name' => 'chrome', 'version' => '131.0.6778.85' },
                             'viewport' => { 'width' => 1920, 'height' => 1080 }, 'device_pixel_ratio' => 2,
                             'capabilities' => { 'network' => false, 'console' => false, 'screenshots' => true, 'snapshots' => true },
                             'truncated' => { 'steps' => 0, 'screenshots' => 0, 'snapshots' => 0, 'network' => 0, 'console' => 0 })
    expect(trace['finished_at'] >= trace['started_at']).to be(true)
  end

  it 'records navigate and click steps in order with index, kind, action, locator, source, waited_ms, retries' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    act(recorder, :click, 'go', label: 'login_button', within: [{ strategy: 'css', selector: '.form' }])
    steps = kept(recorder)['steps']

    expect(steps.map { |step| step.values_at('index', 'kind', 'action') }).to eq([[1, 'navigate', 'navigate'], [2, 'action', 'click']])
    expect(steps.first).to include('parent_index' => nil, 'locator' => nil, 'url' => 'https://example.test/login', 'page_title' => 'Login',
                                   'waited_ms' => 0, 'retries' => 0, 'status' => 'passed', 'error' => nil, 'rect' => nil,
                                   'screenshot' => 'steps/0001.png', 'snapshot' => 'steps/0001.html')
    expect(steps.last).to include('locator' => { 'strategy' => 'id', 'selector' => 'go', 'label' => 'login_button',
                                                 'within' => [{ 'strategy' => 'css', 'selector' => '.form' }] },
                                  'source' => { 'file' => 'spec/login_page_spec.rb', 'line' => 12 },
                                  'waited_ms' => 95, 'retries' => 1, 'status' => 'passed',
                                  'screenshot' => 'steps/0002.png', 'snapshot' => 'steps/0002.html')
    expect(steps.last['duration_ms']).to be_a(Integer)
  end

  it 'gives query actions a step without screenshot or snapshot' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    %i[text attribute displayed? enabled? selected? find_element find_elements].each { |query| act(recorder, query, 'welcome') }
    path = recorder.stop(keep: true, test: failed_test.merge(status: 'passed'))
    trace, names = TraceFormatChecker.read(path)

    queries = trace['steps'].drop(1)
    expect(queries.map { |step| step['action'] }).to eq(%w[text attribute displayed? enabled? selected? find_element find_elements])
    expect(queries.map { |step| step.values_at('screenshot', 'snapshot') }.uniq).to eq([[nil, nil]])
    expect(queries.map { |step| step['url'] }.uniq).to eq(['https://example.test/login'])
    expect(names).to contain_exactly('trace.json', 'steps/0001.png', 'steps/0001.html')
  end

  it 'keeps only the last pass of eventually as child steps and counts the earlier passes in retries' do
    recorder = started_recorder
    group = recorder.group_started(action: :eventually, source: source)
    2.times do |pass|
      act(recorder, :click, 'refresh')
      act(recorder, :text, 'welcome', status: :failed, error: RuntimeError.new("not yet #{pass}"))
      recorder.group_retried(group, error: RuntimeError.new("not yet #{pass}"))
    end
    act(recorder, :click, 'refresh')
    act(recorder, :text, 'welcome')
    recorder.group_finished(group, status: :passed, retries: 2, error: nil)
    steps = kept(recorder)['steps']

    expect(steps.map { |step| step.values_at('index', 'parent_index', 'kind', 'action', 'status') })
      .to eq([[1, nil, 'group', 'eventually', 'passed'], [2, 1, 'action', 'click', 'passed'], [3, 1, 'action', 'text', 'passed']])
    expect(steps.first).to include('retries' => 2, 'error' => 'RuntimeError: not yet 1', 'screenshot' => nil, 'snapshot' => nil)
  end

  it 'appends a failure step with the error when no traced step was running' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    act(recorder, :text, 'welcome')
    steps = kept(recorder, failed_test.merge(error: RSpec::Expectations::ExpectationNotMetError.new('expected "Hi"')))['steps']

    expect(steps.size).to eq(3)
    expect(steps.last).to include('index' => 3, 'kind' => 'failure', 'status' => 'failed', 'locator' => nil,
                                  'error' => 'RSpec::Expectations::ExpectationNotMetError: expected "Hi"',
                                  'screenshot' => 'steps/0003.png', 'snapshot' => 'steps/0003.html')
  end

  it 'marks the step that raised as failed and appends no failure step when that step owns the error' do
    recorder = started_recorder
    error = RuntimeError.new('Waited 10s for {id: "go"} to be visible')
    act(recorder, :click, 'go', status: :failed, error: error)
    steps = kept(recorder, failed_test.merge(error: error))['steps']

    expect(steps.map { |step| step.values_at('kind', 'status', 'error') })
      .to eq([['action', 'failed', 'RuntimeError: Waited 10s for {id: "go"} to be visible']])
  end

  it 'records screenshot: null and keeps going when the screenshot lambda raises' do
    recorder = started_recorder(screenshot: ->(_driver) { raise 'browser gone' })
    recorder.navigated('https://example.test/login')
    act(recorder, :click, 'go')
    steps = kept(recorder, failed_test.merge(error: RuntimeError.new('boom')))['steps']

    expect(steps.map { |step| step['kind'] }).to eq(%w[navigate action failure])
    expect(steps.map { |step| step['screenshot'] }).to eq([nil, nil, nil])
    expect(steps.map { |step| step['snapshot'] }).to eq(%w[steps/0001.html steps/0002.html steps/0003.html])
    expect(warnings).to eq(["[trace] screenshot not captured: browser gone\n"])
    expect(TraceHelper.enabled?).to be(true)
  end

  describe 'size cap' do
    let(:shot_bytes) { 4000 }

    # 15 click steps with incompressible media, and 40 network entries.
    def capped(max_mb)
      allow(TraceHelper).to receive(:config).and_return(trace_config.merge('max_mb' => max_mb))
      recorder = started_recorder(screenshot: ->(_driver) { [Random.bytes(shot_bytes), 'png'] },
                                  snapshot: ->(_driver) { Random.bytes(3000).unpack1('H*') })
      15.times do |step|
        act(recorder, :click, "button-#{step}")
        3.times { |request| recorder.network_event(method: 'GET', url: "https://example.test/#{step}/#{request}?q=#{Random.new((step * 3) + request).bytes(16).unpack1('H*')}", status: 200) }
      end
      path = recorder.stop(keep: true, test: failed_test)
      expect(TraceFormatChecker.problems(path)).to eq([])
      [TraceFormatChecker.read(path).first, File.size(path), path]
    end

    def nulls(trace, key)
      trace['steps'].map { |step| step[key].nil? }
    end

    it 'stays under max_mb, dropping oldest HTML, then oldest screenshots, then oldest network and console, never the last 10 steps, and counts drops in truncated' do
      full, full_size, full_path = capped(20)
      html_size, old_media = Zip::File.open(full_path) do |zip|
        old = zip.entries.select { |entry| entry.name < 'steps/0006' && entry.name != 'trace.json' }
        [zip.find_entry('steps/0001.html').compressed_size, old.sum { |entry| entry.compressed_size + 76 + (2 * entry.name.bytesize) }]
      end
      expect(full['truncated'].values.sum).to eq(0)

      limits = { html: full_size - (1.5 * html_size), shots: full_size - (5 * html_size) - (1.5 * shot_bytes),
                 events: full_size - old_media - 300 }
      traces = limits.transform_values do |bytes|
        trace, size, = capped(bytes / 1024.0 / 1024)
        expect(size).to be <= bytes
        trace
      end

      expect(nulls(traces[:html], 'snapshot')).to eq([true] * 2 + [false] * 13)
      expect(nulls(traces[:html], 'screenshot')).to eq([false] * 15)
      expect(nulls(traces[:shots], 'snapshot')).to eq([true] * 5 + [false] * 10)
      expect(nulls(traces[:shots], 'screenshot')).to eq([true] * 2 + [false] * 13)
      expect(nulls(traces[:events], 'screenshot')).to eq([true] * 5 + [false] * 10)
      dropped = traces[:events]['truncated']['network']
      expect(dropped).to be_positive
      expect(traces[:events]['network'].map { |entry| entry['url'] }).to eq(full['network'].drop(dropped).map { |entry| entry['url'] })
      expect(traces.values.map { |trace| trace['truncated'].values_at('snapshots', 'screenshots') }).to eq([[2, 0], [5, 2], [5, 5]])
    end
  end

  it 'keeps at most max_steps steps, newest kept' do
    allow(TraceHelper).to receive(:config).and_return(trace_config.merge('max_steps' => 5))
    recorder = started_recorder
    8.times { |step| act(recorder, :click, "button-#{step}") }
    path = recorder.stop(keep: true, test: failed_test.merge(status: 'passed'))
    trace, names = TraceFormatChecker.read(path)

    expect(TraceFormatChecker.problems(path)).to eq([])
    expect(trace['steps'].map { |step| [step['index'], step['locator']['selector']] })
      .to eq([[1, 'button-3'], [2, 'button-4'], [3, 'button-5'], [4, 'button-6'], [5, 'button-7']])
    expect(trace['truncated']['steps']).to eq(3)
    expect(names.size).to eq(11)
  end

  it 'returns nil and writes nothing for stop(keep: false)' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')

    expect(recorder.stop(keep: false, test: failed_test)).to be_nil
    expect(Dir.glob(File.join(project_dir, 'tmp', '**', 'trace.zip'))).to be_empty
    recorder.cleanup
    expect(Dir.children(File.join(project_dir, 'tmp'))).to be_empty
  end

  it 'makes the recorder the WaitHelper observer until cleanup, so no test inherits it' do
    recorder = started_recorder
    expect(WaitHelper.observer).to be(recorder)

    recorder.stop(keep: false, test: failed_test)
    recorder.cleanup
    expect(WaitHelper.observer).to be_nil
  end

  it 'records navigation and the failure without WaitHelper' do
    hide_const('WaitHelper')
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    steps = kept(recorder, failed_test.merge(error: RuntimeError.new('boom')))['steps']

    expect(steps.map { |step| step['kind'] }).to eq(%w[navigate failure])
  end

  context 'with TRACE=off' do
    let(:env) { { 'TRACE' => 'off' } }

    it 'returns a NullRecorder and leaves WaitHelper.observer nil with TRACE=off or enabled: false' do
      recorder = TraceHelper.recorder_for(driver)

      expect(recorder).to be_a(TraceHelper::NullRecorder)
      expect(recorder.start).to be_nil
      expect(recorder.stop(keep: true, test: failed_test)).to be_nil
      expect(WaitHelper.observer).to be_nil
    end
  end

  context 'with enabled: false' do
    let(:trace_config) { { 'enabled' => false } }

    it 'returns a NullRecorder and leaves WaitHelper.observer nil with TRACE=off or enabled: false' do
      expect(TraceHelper.recorder_for(driver)).to be_a(TraceHelper::NullRecorder)
      expect(WaitHelper.observer).to be_nil
    end
  end

  context 'with TRACE=on' do
    let(:env) { { 'TRACE' => 'on' } }

    it 'keeps every trace' do
      expect(TraceHelper.keep_all?).to be(true)
    end
  end

  it 'keeps failing traces only with TRACE unset' do
    expect(TraceHelper.keep_all?).to be(false)
    expect(TraceHelper.config).to eq(trace_config)
  end

  it 'stores images uncompressed and JSON/HTML deflated, readable by rubyzip, with steps/NNNN names' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    path = recorder.stop(keep: true, test: failed_test)

    Zip::File.open(path) do |zip|
      methods = zip.entries.to_h { |entry| [entry.name, entry.compression_method] }
      expect(methods).to eq('trace.json' => Zip::Entry::DEFLATED, 'steps/0001.png' => Zip::Entry::STORED,
                            'steps/0001.html' => Zip::Entry::DEFLATED)
      expect(zip.read('steps/0001.png')).to eq(png)
      expect(zip.read('steps/0001.html')).to eq(html)
    end
  end

  it 'turns tracing off for the run after one [trace] warning when writing the zip fails' do
    allow(TraceHelper::ZipWriter).to receive(:write).and_raise(Errno::ENOSPC)
    2.times do
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      expect(recorder.stop(keep: true, test: failed_test)).to be_nil
    end

    expect(warnings).to eq(["[trace] could not write the trace: No space left on device; tracing disabled for this run\n"])
    expect(TraceHelper.enabled?).to be(false)
    expect(TraceHelper.recorder_for(driver)).to be_a(TraceHelper::NullRecorder)
    expect(WaitHelper.observer).to be_nil
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/ExpectOutput, RSpec/MultipleExpectations, RSpec/ExampleLength
