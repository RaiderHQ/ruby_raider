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

  # What WaitHelper reports for one action. With an element, it was found ready (action_ready).
  def act(recorder, action, selector, status: :passed, error: nil, label: nil, within: [], args: nil, element: nil)
    token = recorder.action_started(action: action, locator: { strategy: 'id', selector: selector }, within: within,
                                    source: source, label: label, args: args)
    recorder.action_ready(token, element: element) if element
    recorder.action_finished(token, status: status, waited_ms: 95, retries: 1, error: error, element: element)
  end

  # What Page.capture's script answers: the inlined CSS, the sheets it could not read and the title.
  def page_script(css: '', skipped: 0, title: 'Login')
    allow(driver).to receive(:execute_script).with(/styleSheets/).and_return('css' => css, 'skipped' => skipped, 'title' => title)
  end

  # What Page.element_info's script answers for one element.
  def element_script(element, secret: false, tag: 'input', label: 'Password', role: 'textbox')
    info = { 'rect' => { 'x' => 640, 'y' => 312, 'width' => 320, 'height' => 40 }, 'tag' => tag, 'label' => label,
             'role' => role, 'secret' => secret }
    allow(driver).to receive(:execute_script).with(/getBoundingClientRect/, element).and_return(info)
  end

  def snapshot_of(path, index)
    Zip::File.open(path) { |zip| zip.read(format('steps/%04d.html', index)) }
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
                                         'status' => 'failed', 'attempt' => 2, 'error' => nil },
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
    expect(steps.first).to include('retries' => 2, 'error' => { 'class' => 'RuntimeError', 'message' => 'not yet 1' }, 'screenshot' => nil, 'snapshot' => nil)
  end

  it 'appends a failure step with the error when no traced step was running' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    act(recorder, :text, 'welcome')
    trace = kept(recorder, failed_test.merge(error: RSpec::Expectations::ExpectationNotMetError.new('expected "Hi"')))
    steps = trace['steps']
    error = { 'class' => 'RSpec::Expectations::ExpectationNotMetError', 'message' => 'expected "Hi"' }

    expect(trace['test']['error']).to eq(error)
    expect(steps.size).to eq(3)
    expect(steps.last).to include('index' => 3, 'kind' => 'failure', 'status' => 'failed', 'locator' => nil, 'error' => error,
                                  'screenshot' => 'steps/0003.png', 'snapshot' => 'steps/0003.html')
  end

  it 'marks the step that raised as failed and appends no failure step when that step owns the error' do
    recorder = started_recorder
    error = RuntimeError.new('Waited 10s for {id: "go"} to be visible')
    act(recorder, :click, 'go', status: :failed, error: error)
    steps = kept(recorder, failed_test.merge(error: error))['steps']

    expect(steps.map { |step| step.values_at('kind', 'status', 'error') })
      .to eq([['action', 'failed', { 'class' => 'RuntimeError', 'message' => 'Waited 10s for {id: "go"} to be visible' }]])
  end

  it 'still gives the test error a step when the step that raised it was dropped by eventually' do
    recorder = started_recorder
    error = RuntimeError.new('not yet')
    group = recorder.group_started(action: :eventually, source: source)
    act(recorder, :click, 'refresh', status: :failed, error: error)
    recorder.group_retried(group, error: error)
    act(recorder, :click, 'refresh')
    recorder.group_finished(group, status: :passed, retries: 1, error: nil)
    steps = kept(recorder, failed_test.merge(error: error))['steps']

    expect(steps.map { |step| step.values_at('kind', 'status') }).to eq([%w[group passed], %w[action passed]])
    expect(steps.first['error']).to eq('class' => 'RuntimeError', 'message' => 'not yet')
  end

  it 'appends a failure step when the step that raised the test error was dropped by max_steps' do
    allow(TraceHelper).to receive(:config).and_return(trace_config.merge('max_steps' => 2))
    recorder = started_recorder
    error = RuntimeError.new('gone')
    act(recorder, :click, 'first', status: :failed, error: error)
    2.times { act(recorder, :click, 'later') }
    steps = kept(recorder, failed_test.merge(error: error))['steps']

    expect(steps.map { |step| step['kind'] }).to eq(%w[action failure])
    expect(steps.last['error']).to eq('class' => 'RuntimeError', 'message' => 'gone')
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

  describe 'snapshots' do
    def sanitize(page, css: '', skipped: 0)
      TraceHelper::Snapshot.sanitize(page, css: css, skipped: skipped)
    end

    it 'strips script, on* handlers, javascript: urls, base and meta refresh' do
      page = <<~HTML
        <html><head><base href="https://example.test/"><meta http-equiv="Refresh" content="0;url=/x"><meta charset="utf-8">
        <script src="/app.js"></script><SCRIPT type="module">alert("<p>")</SCRIPT></head>
        <body onload="go()"><a href=" javascript:alert(1)" class="x">a</a><img src='JavaScript:evil()' alt="i">
        <a href="/ok" onclick='x()'>ok</a><button onClick=go type="button">b</button><p title="a > b">t</p></body></html>
      HTML
      clean = sanitize(page)

      expect(clean).not_to match(/script|onload|onclick|javascript:|<base|refresh/i)
      expect(clean).to include('<meta charset="utf-8">', '<a class="x">a</a>', '<img alt="i">', '<a href="/ok">ok</a>',
                               '<button type="button">b</button>', '<p title="a > b">t</p>', '<body>')
    end

    it 'inlines the page CSS in place of stylesheet links and counts skipped cross-origin sheets' do
      page_script(css: "body { color: red; }\np::after { content: \"</style>\"; }", skipped: 2)
      allow(driver).to receive(:page_source).and_return(<<~HTML)
        <html lang="en"><head><link rel="stylesheet" href="/a.css"><link href="https://cdn.test/b.css" REL='Stylesheet'>
        <style>p { margin: 0; }</style><link rel="icon" href="/favicon.ico"></head><body><p>hi</p></body></html>
      HTML
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      path = recorder.stop(keep: true, test: failed_test)
      snapshot = snapshot_of(path, 1)

      expect(TraceFormatChecker.problems(path)).to eq([])

      expect(snapshot.scan(/<style/i).size).to eq(1)
      expect(snapshot).to include('<html lang="en" data-raider-skipped-sheets="2">', 'body { color: red; }',
                                  'content: "<\\/style>"', '<link rel="icon" href="/favicon.ico">', '<p>hi</p>')
      expect(snapshot).not_to match(/stylesheet|margin: 0/i)
    end

    it 'adds no base element' do
      clean = sanitize('<html><head><title>t</title></head><body><a href="/x">x</a></body></html>', css: 'a { color: red; }')

      expect(clean).not_to match(/<base/i)
      expect(clean).to include('<html data-raider-skipped-sheets="0">', '<style>a { color: red; }</style></head>')
    end

    it 'counts the stylesheet links it removed as skipped, and keeps <style>, when the CSS could not be read' do
      page = '<html data-raider-skipped-sheets="9" lang="en"><head><link rel="stylesheet" href="/a.css"><link rel="stylesheet" href="/b.css">' \
             '<style>p { margin: 0; }</style></head><body></body></html>'

      expect(sanitize(page, css: nil)).to eq('<html lang="en" data-raider-skipped-sheets="2"><head><style>p { margin: 0; }</style></head><body></body></html>')
    end
  end

  describe 'typed values and element info' do
    let(:field) { double('field') }

    before { page_script }

    def typed_step(recorder, args, action: :send_keys)
      act(recorder, action, 'field', args: args, element: field)
      kept(recorder)['steps'].last
    end

    it 'masks a password field: value null, secret true, and a blank value attribute in the snapshot' do
      element_script(field, secret: true)
      allow(driver).to receive(:page_source).and_return('<html><body><input type="password" name="pw" value="hunter2"></body></html>')
      recorder = started_recorder
      act(recorder, :send_keys, 'pw', args: ['hunter2'], element: field)
      path = recorder.stop(keep: true, test: failed_test)
      step = TraceFormatChecker.read(path).first['steps'].last

      expect(TraceFormatChecker.problems(path)).to eq([])
      expect(step).to include('value' => nil, 'secret' => true)
      expect(snapshot_of(path, 1)).to include('<input type="password" name="pw" value="">')
      expect(Zip::File.open(path) { |zip| zip.entries.map { |entry| zip.read(entry.name) }.join }).not_to include('hunter2')
    end

    it 'masks a type=text field whose autocomplete contains password' do
      element_script(field, secret: true)
      clean = TraceHelper::Snapshot.sanitize(
        "<input value='s3cret' AUTOCOMPLETE=\"New-Password\" type=text><input value=keep type=text autocomplete=username>",
        css: nil, skipped: 0
      )

      expect(typed_step(started_recorder, ['s3cret'])).to include('value' => nil, 'secret' => true)
      expect(clean).to eq('<input value="" AUTOCOMPLETE="New-Password" type=text><input value=keep type=text autocomplete=username>')
    end

    context 'with a RAIDER_SECRET_* value set' do
      let(:env) { { 'RAIDER_SECRET_ADMIN' => 'pa55word' } }

      it 'masks a value equal to a RAIDER_SECRET_* env value typed into a plain field' do
        element_script(field, secret: false, label: 'Notes')
        recorder = started_recorder
        act(recorder, :send_keys, 'notes', args: ['pa55word'], element: field)
        act(recorder, :send_keys, 'notes', args: ['pa55word', :enter], element: field)
        steps = kept(recorder)['steps']

        expect(steps.map { |step| step.values_at('value', 'secret') }).to eq([[nil, true], [nil, true]])
      end
    end

    it 'keeps other typed values as typed' do
      element_script(field, secret: false)
      recorder = started_recorder
      act(recorder, :send_keys, 'user', args: ['admin', :enter], element: field)
      act(recorder, :select_by, 'colour', args: [:text, 'Blue'], element: field)
      act(recorder, :click, 'go', element: field)
      steps = kept(recorder)['steps']

      expect(steps.map { |step| step.values_at('value', 'secret') }).to eq([['admin{enter}', false], ['Blue', false], [nil, nil]])
      expect(steps.last.keys).not_to include('value', 'secret')
    end

    it 'records rect, element tag, label and role from element_info' do
      element_script(field, tag: 'button', label: 'Log in', role: 'button')
      recorder = started_recorder
      act(recorder, :click, 'go', element: field)
      act(recorder, :text, 'go', element: field)
      steps = kept(recorder)['steps']

      expect(steps.first).to include('rect' => { 'x' => 640, 'y' => 312, 'width' => 320, 'height' => 40 },
                                     'element' => { 'tag' => 'button', 'label' => 'Log in', 'role' => 'button' })
      expect(steps.first.keys.first(8)).to eq(%w[index parent_index kind action locator element url page_title])
      expect(steps.last).to include('rect' => nil)
      expect(steps.last.keys).not_to include('element')
      expect(driver).to have_received(:execute_script).with(/getBoundingClientRect/, field).once
    end

    it 'skips the screenshot while an alert is open' do
      alert = { open: true }
      stub_const('VideoHelper', Module.new { define_singleton_method(:alert_open?) { |_driver| alert[:open] } })
      shots = []
      recorder = started_recorder(screenshot: ->(_driver) { shots << :shot && [png, 'png'] })
      act(recorder, :click, 'go', element: field)
      alert[:open] = false
      act(recorder, :click, 'ok', element: field)
      steps = kept(recorder)['steps']

      expect(steps.map { |step| step.values_at('screenshot', 'snapshot') }).to eq([[nil, nil], ['steps/0002.png', 'steps/0002.html']])
      expect(shots).to eq([:shot])
      expect(driver).to have_received(:page_source).once
    end
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
      expect(zip.read('steps/0001.html')).to eq(html.sub('<html>', '<html data-raider-skipped-sheets="0">'))
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
