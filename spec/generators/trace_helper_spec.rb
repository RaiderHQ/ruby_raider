# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'stringio'
require 'tmpdir'
require 'yaml'
require 'zip'
require_relative '../../lib/generators/helper_generator'
require_relative '../integration/trace_format_checker'

$LOAD_PATH.unshift(File.expand_path('fixtures/video_helper_stubs', __dir__))
require 'selenium-webdriver'

# Stands in for Selenium::WebDriver::BiDi (4.52): session.subscribe(events), add_callback(event, &block)
# and send_cmd(method, **params). emit delivers an event on its own thread, as the websocket does.
class FakeTraceBidi
  attr_reader :subscribed, :callbacks, :commands
  attr_accessor :failure, :screenshot

  def initialize(screenshot)
    @screenshot = screenshot
    @subscribed = []
    @callbacks = Hash.new { |hash, event| hash[event] = [] }
    @commands = []
  end

  def session
    self
  end

  def subscribe(events, _browsing_contexts = nil)
    raise failure if failure

    @subscribed << Array(events)
    {}
  end

  def add_callback(event, &block)
    @callbacks[event] << block
    block.object_id
  end

  def send_cmd(method, **params)
    @commands << [method, params]
    raise screenshot if screenshot.is_a?(Exception)

    { 'data' => [screenshot].pack('m0') }
  end

  def emit(event, params)
    @callbacks[event].each { |callback| Thread.new { callback.call(params) }.join }
  end
end

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
  let(:jpeg) { "\xFF\xD8\xFFfake-jpeg".b }
  let(:bidi) { FakeTraceBidi.new(jpeg) }
  let(:html) { "<html><head><title>Login</title></head><body>#{'<p>row</p>' * 50}</body></html>" }
  let(:capabilities) { double('capabilities', browser_name: 'chrome', browser_version: '131.0.6778.85') }
  let(:window) { double('window', size: double('size', width: 1920, height: 1080)) }
  let(:driver) do
    double('driver', screenshot_as: png, page_source: html, current_url: 'https://example.test/login', title: 'Login',
                     capabilities: capabilities, manage: double('manage', window: window), execute_script: 2,
                     bidi: bidi, window_handle: 'context-1')
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
  def act(recorder, action, selector, status: :passed, error: nil, within: [], args: nil, element: nil)
    token = recorder.action_started(action: action, locator: { strategy: 'id', selector: selector }, within: within,
                                    source: source, args: args)
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
                             'capabilities' => { 'network' => true, 'console' => true, 'screenshots' => true, 'snapshots' => true },
                             'truncated' => { 'steps' => 0, 'screenshots' => 0, 'snapshots' => 0, 'network' => 0, 'console' => 0 })
    expect(trace['finished_at'] >= trace['started_at']).to be(true)
  end

  it 'records navigate and click steps in order with index, kind, action, locator, source, waited_ms, retries' do
    recorder = started_recorder
    recorder.navigated('https://example.test/login')
    act(recorder, :click, 'go', within: [{ strategy: 'css', selector: '.form' }])
    steps = kept(recorder)['steps']

    expect(steps.map { |step| step.values_at('index', 'kind', 'action') }).to eq([[1, 'navigate', 'navigate'], [2, 'action', 'click']])
    expect(steps.first).to include('parent_index' => nil, 'locator' => nil, 'url' => 'https://example.test/login', 'page_title' => 'Login',
                                   'waited_ms' => 0, 'retries' => 0, 'status' => 'passed', 'error' => nil, 'rect' => nil,
                                   'screenshot' => 'steps/0001.jpg', 'snapshot' => 'steps/0001.html')
    # No locator.label: a page object's element method has returned before the action runs, so it is never known.
    expect(steps.last).to include('locator' => { 'strategy' => 'id', 'selector' => 'go',
                                                 'within' => [{ 'strategy' => 'css', 'selector' => '.form' }] },
                                  'source' => { 'file' => 'spec/login_page_spec.rb', 'line' => 12 },
                                  'waited_ms' => 95, 'retries' => 1, 'status' => 'passed',
                                  'screenshot' => 'steps/0002.jpg', 'snapshot' => 'steps/0002.html')
    expect(steps.last['duration_ms']).to be_a(Integer)
  end

  it 'leaves locator.label optional in the format checker: a string is allowed, anything else is a problem' do
    locator = { 'strategy' => 'id', 'selector' => 'password' }

    expect(TraceFormatChecker.locator_rules('steps[0]', locator)).to eq([])
    expect(TraceFormatChecker.locator_rules('steps[0]', locator.merge('label' => 'password_field'))).to eq([])
    expect(TraceFormatChecker.locator_rules('steps[0]', locator.merge('label' => 3))).to eq(['steps[0].locator.label is not a string'])
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
    expect(names).to contain_exactly('trace.json', 'steps/0001.jpg', 'steps/0001.html')
  end

  it 'records a Cucumber step as a cucumber_step group carrying its name, with the actions it ran as children' do
    recorder = started_recorder
    group = recorder.step_started(name: 'When I log in as admin', source: source)
    act(recorder, :click, 'login')
    recorder.step_finished(group, status: :passed, error: nil)
    act(recorder, :click, 'outside')
    steps = kept(recorder)['steps']

    expect(steps.map { |step| step.values_at('index', 'parent_index', 'kind', 'action', 'status', 'name') })
      .to eq([[1, nil, 'group', 'cucumber_step', 'passed', 'When I log in as admin'], [2, 1, 'action', 'click', 'passed', nil],
              [3, nil, 'action', 'click', 'passed', nil]])
    expect(steps[1..].map { |step| step.key?('name') }).to eq([false, false])
  end

  it 'records a failed Cucumber step with its error' do
    recorder = started_recorder
    group = recorder.step_started(name: 'Then I see the dashboard', source: source)
    recorder.step_finished(group, status: :failed, error: RuntimeError.new('no dashboard'))
    step = kept(recorder)['steps'].first

    expect(step).to include('status' => 'failed', 'error' => { 'class' => 'RuntimeError', 'message' => 'no dashboard' })
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
                                  'screenshot' => 'steps/0003.jpg', 'snapshot' => 'steps/0003.html')
  end

  it 'gives an error of an anonymous class a string class, which the format requires' do
    error = Class.new(StandardError).new('anonymous')

    expect(TraceHelper.error_json(error)).to eq(class: error.class.to_s, message: 'anonymous')
    expect(TraceHelper.error_json(error)[:class]).to start_with('#<Class:')
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

    it 'keeps a masked value out of later snapshots after the page switches the field to type=text' do
      element_script(field, secret: true)
      allow(driver).to receive(:page_source).and_return('<html><body><input type="text" name="pw" value="hunter2"></body></html>')
      recorder = started_recorder
      act(recorder, :send_keys, 'pw', args: ['hunter2'], element: field)
      act(recorder, :click, 'show-password', element: field)
      path = recorder.stop(keep: true, test: failed_test)

      expect(TraceFormatChecker.problems(path)).to eq([])
      expect(snapshot_of(path, 2)).to include('<input type="text" name="pw" value="">')
      expect(Zip::File.open(path) { |zip| zip.entries.map { |entry| zip.read(entry.name) } }).to all(satisfy { |bytes| !bytes.include?('hunter2') })
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
        allow(driver).to receive(:page_source).and_return('<html><body><input type="text" name="notes" value="pa55word"></body></html>')
        recorder = started_recorder
        act(recorder, :send_keys, 'notes', args: ['pa55word'], element: field)
        act(recorder, :send_keys, 'notes', args: ['pa55word', :enter], element: field)
        path = recorder.stop(keep: true, test: failed_test)
        steps = TraceFormatChecker.read(path).first['steps']

        expect(TraceFormatChecker.problems(path)).to eq([])
        expect(steps.map { |step| step.values_at('value', 'secret') }).to eq([[nil, true], [nil, true]])
        expect(snapshot_of(path, 1)).to include('<input type="text" name="notes" value="">')
        expect(Zip::File.open(path) { |zip| zip.entries.map { |entry| zip.read(entry.name) } }).to all(satisfy { |bytes| !bytes.include?('pa55word') })
      end
    end

    context 'with a RAIDER_SECRET_* value holding & and "' do
      let(:env) { { 'RAIDER_SECRET_TOKEN' => 'a&b"c' } }

      it 'blanks the value attribute the browser wrote entity-encoded, and keeps it out of every zip entry' do
        element_script(field, secret: false, label: 'Notes')
        allow(driver).to receive(:page_source).and_return('<html><body><input type="text" name="notes" value="a&amp;b&quot;c"></body></html>')
        recorder = started_recorder
        act(recorder, :send_keys, 'notes', args: ['a&b"c'], element: field)
        path = recorder.stop(keep: true, test: failed_test)
        entries = Zip::File.open(path) { |zip| zip.entries.map { |entry| zip.read(entry.name) } }

        expect(TraceFormatChecker.problems(path)).to eq([])
        expect(snapshot_of(path, 1)).to include('<input type="text" name="notes" value="">')
        expect(entries).to all(satisfy { |bytes| !bytes.include?('a&amp;b&quot;c') && !bytes.include?('a&b"c') && !bytes.include?('a&b\\"c') })
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

  it 'treats max_steps above 9999 as 9999, so step entries stay steps/NNNN, and a non-positive one as the default' do
    { 50_000 => 9999, 9999 => 9999, 1 => 1, 0 => 200, -3 => 200 }.each do |configured, used|
      allow(TraceHelper).to receive(:config).and_return(trace_config.merge('max_steps' => configured))
      expect(TraceHelper.max_steps).to eq(used), "max_steps: #{configured}"
    end
    expect(warnings).to eq([])
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
      expect(methods).to eq('trace.json' => Zip::Entry::DEFLATED, 'steps/0001.jpg' => Zip::Entry::STORED,
                            'steps/0001.html' => Zip::Entry::DEFLATED)
      expect(zip.read('steps/0001.jpg')).to eq(jpeg)
      expect(zip.read('steps/0001.html')).to eq(html.sub('<html>', '<html data-raider-skipped-sheets="0">'))
    end
  end

  it 'prints the no-BiDi notice and then the disable line when a Safari run fails to write its zip' do
    allow(capabilities).to receive(:browser_name).and_return('Safari')
    allow(TraceHelper::ZipWriter).to receive(:write).and_raise(Errno::ENOSPC)
    2.times do
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      recorder.stop(keep: true, test: failed_test)
    end

    expect(warnings).to eq(["[trace] network and console not captured: Safari has no WebDriver BiDi\n",
                            "[trace] could not write the trace: No space left on device; tracing disabled for this run\n"])
    expect(TraceHelper.enabled?).to be(false)
  end

  it 'prints a media miss and then the disable line, at most one of each' do
    allow(TraceHelper::ZipWriter).to receive(:write).and_raise(Errno::ENOSPC)
    recorder = started_recorder(screenshot: ->(_driver) { raise 'browser gone' })
    2.times { recorder.navigated('https://example.test/login') }
    recorder.stop(keep: true, test: failed_test)
    TraceHelper.disable!('a second reason')

    expect(warnings).to eq(["[trace] screenshot not captured: browser gone\n",
                            "[trace] could not write the trace: No space left on device; tracing disabled for this run\n"])
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

  describe 'a navigation in flight' do
    let(:started_ms) { 1_793_568_600_020 }

    def request_sent(id, url)
      bidi.emit('network.beforeRequestSent', 'request' => { 'request' => id, 'method' => 'GET', 'url' => url },
                                             'timestamp' => started_ms)
    end

    it 'credits requests made between navigating and navigated to the navigate step' do
      recorder = started_recorder
      recorder.navigating('https://example.test/start')
      request_sent('r1', 'https://example.test/start')
      recorder.navigated('https://example.test/')
      act(recorder, :click, 'go')
      request_sent('r2', 'https://example.test/api')
      trace = kept(recorder)

      expect(trace['steps'].map { |step| step.values_at('index', 'action', 'status') }).to eq([[1, 'navigate', 'passed'], [2, 'click', 'passed']])
      expect(trace['network'].map { |entry| entry.values_at('step_index', 'url') })
        .to eq([[1, 'https://example.test/start'], [2, 'https://example.test/api']])
    end

    it 'keeps the old path: navigated alone adds one finished navigate step' do
      recorder = started_recorder
      recorder.navigated('https://example.test/login')

      expect(kept(recorder)['steps'].map { |step| step.values_at('kind', 'status') }).to eq([%w[navigate passed]])
    end

    it 'finishes a navigation that never completed as failed at the next navigating' do
      recorder = started_recorder
      recorder.navigating('https://example.test/down')
      recorder.navigating('https://example.test/up')
      recorder.navigated('https://example.test/up')
      steps = kept(recorder)['steps']

      expect(steps.map { |step| step.values_at('kind', 'status', 'url') })
        .to eq([['navigate', 'failed', 'https://example.test/down'], ['navigate', 'passed', 'https://example.test/login']])
    end

    it 'finishes a navigation that never completed as failed at stop' do
      recorder = started_recorder
      recorder.navigating('https://example.test/down')
      steps = kept(recorder)['steps']

      expect(steps.map { |step| step.values_at('kind', 'status') }).to eq([%w[navigate failed]])
    end

    it 'is driven by the listener before each navigation, and the null recorder ignores it' do
      listener = TraceHelper.listener
      recorder = started_recorder
      listener.before_navigate_to('https://example.test/a', driver)
      listener.after_navigate_to('https://example.test/a', driver)
      listener.before_navigate_back(driver)
      listener.after_navigate_back(driver)
      listener.before_navigate_forward(driver)
      listener.after_navigate_forward(driver)

      expect(kept(recorder)['steps'].map { |step| step['status'] }).to eq(%w[passed passed passed])
      expect(TraceHelper::NullRecorder.new.navigating('https://example.test/')).to be_nil
    end
  end

  describe 'browser wiring' do
    let(:started_ms) { 1_793_568_600_020 }
    let(:bidi_events) { %w[network.beforeRequestSent network.responseCompleted network.fetchError log.entryAdded] }

    def request_sent(id, method, url, at, hop: 0)
      bidi.emit('network.beforeRequestSent', 'redirectCount' => hop,
                                             'request' => { 'request' => id, 'method' => method, 'url' => url,
                                                            'headers' => [{ 'name' => 'Cookie', 'value' => { 'type' => 'string', 'value' => 'session=hush' } }] },
                                             'timestamp' => at)
    end

    it 'subscribes passively to the four BiDi events and never adds a request handler' do
      first = started_recorder
      first.stop(keep: false, test: failed_test)
      second = started_recorder
      bidi.emit('log.entryAdded', 'type' => 'console', 'level' => 'info', 'text' => 'second test', 'timestamp' => started_ms)

      expect(bidi.subscribed).to eq([bidi_events])
      expect(bidi.callbacks.keys).to match_array(bidi_events)
      expect(bidi.commands.map(&:first)).not_to include('network.addIntercept')
      expect(kept(second)['console'].map { |entry| entry['text'] }).to eq(['second test'])
    end

    it 'maps beforeRequestSent and responseCompleted into one network entry with step_index, method, url, status, mime_type, duration_ms, bytes' do
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      request_sent('r1', 'GET', 'https://example.test/app.js', started_ms)
      act(recorder, :click, 'go')
      bidi.emit('network.responseCompleted',
                'request' => { 'request' => 'r1', 'url' => 'https://example.test/app.js' }, 'timestamp' => started_ms + 210,
                'response' => { 'status' => 200, 'mimeType' => 'text/javascript', 'bytesReceived' => 18_234,
                                'headers' => [{ 'name' => 'Set-Cookie', 'value' => { 'type' => 'string', 'value' => 'session=hush' } }] })
      request_sent('r2', 'POST', 'https://example.test/api', started_ms + 300)
      bidi.emit('network.fetchError', 'request' => { 'request' => 'r2' }, 'errorText' => 'net::ERR_CONNECTION_REFUSED',
                                      'timestamp' => started_ms + 305)
      path = recorder.stop(keep: true, test: failed_test)

      expect(TraceFormatChecker.problems(path)).to eq([])
      expect(TraceFormatChecker.read(path).first['network']).to eq(
        [{ 'step_index' => 1, 'method' => 'GET', 'url' => 'https://example.test/app.js', 'status' => 200,
           'mime_type' => 'text/javascript', 'started_at' => '2026-11-01T21:30:00.020Z', 'duration_ms' => 210,
           'bytes' => 18_234, 'error' => nil },
         { 'step_index' => 2, 'method' => 'POST', 'url' => 'https://example.test/api', 'status' => nil, 'mime_type' => nil,
           'started_at' => '2026-11-01T21:30:00.320Z', 'duration_ms' => 5, 'bytes' => nil,
           'error' => 'net::ERR_CONNECTION_REFUSED' }]
      )
      expect(Zip::File.open(path) { |zip| zip.read('trace.json') }).not_to include('hush')
    end

    it 'completes a network entry whose responseCompleted thread ran before its beforeRequestSent' do
      recorder = started_recorder
      bidi.emit('network.responseCompleted', 'request' => { 'request' => 'r1' }, 'timestamp' => started_ms + 40,
                                             'response' => { 'status' => 304, 'mimeType' => 'text/css', 'bytesReceived' => 0 })
      request_sent('r1', 'GET', 'https://example.test/app.css', started_ms)

      expect(kept(recorder)['network']).to eq(
        [{ 'step_index' => 1, 'method' => 'GET', 'url' => 'https://example.test/app.css', 'status' => 304,
           'mime_type' => 'text/css', 'started_at' => '2026-11-01T21:30:00.020Z', 'duration_ms' => 40, 'bytes' => 0,
           'error' => nil }]
      )
    end

    # Seen in Chrome 156: responseCompleted carries the request's start as its timestamp, and the end only in
    # request.timings (ms after timeOrigin). Firefox stamps the event's own time and gives absolute timings.
    it "takes duration_ms from the request's timings when responseCompleted is stamped with the request's start" do
      recorder = started_recorder
      request_sent('chrome', 'GET', 'https://example.test/api', started_ms)
      bidi.emit('network.responseCompleted', 'timestamp' => started_ms, 'response' => { 'status' => 200 },
                                             'request' => { 'request' => 'chrome',
                                                            'timings' => { 'timeOrigin' => started_ms, 'responseEnd' => 310.449 } })
      request_sent('firefox', 'GET', 'https://example.test/api', started_ms)
      bidi.emit('network.responseCompleted', 'timestamp' => started_ms + 301, 'response' => { 'status' => 200 },
                                             'request' => { 'request' => 'firefox',
                                                            'timings' => { 'timeOrigin' => 0, 'responseEnd' => started_ms + 300.6 } })

      expect(kept(recorder)['network'].map { |entry| entry['duration_ms'] }).to eq([310, 301])
    end

    it 'maps log.entryAdded into a console entry with level, text, source, at' do
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      bidi.emit('log.entryAdded',
                'type' => 'javascript', 'level' => 'error', 'text' => 'Uncaught TypeError: x is undefined',
                'timestamp' => started_ms, 'source' => { 'realm' => 'realm-1', 'context' => 'context-1' },
                'stackTrace' => { 'callFrames' => [{ 'url' => 'https://example.test/app.js', 'functionName' => 'go',
                                                     'lineNumber' => 40, 'columnNumber' => 6 }] })
      bidi.emit('log.entryAdded', 'type' => 'console', 'method' => 'log', 'level' => 'info', 'text' => 'ready',
                                  'timestamp' => started_ms + 1, 'source' => { 'realm' => 'realm-1' }, 'args' => [])

      expect(kept(recorder)['console']).to eq(
        [{ 'step_index' => 1, 'level' => 'error', 'text' => 'Uncaught TypeError: x is undefined',
           'source' => 'https://example.test/app.js:41:7', 'at' => '2026-11-01T21:30:00.020Z' },
         { 'step_index' => 1, 'level' => 'info', 'text' => 'ready', 'source' => nil, 'at' => '2026-11-01T21:30:00.021Z' }]
      )
    end

    # A redirect keeps the request id; each hop has its own redirectCount. Chrome starts hop 1 in the same
    # millisecond hop 0 completes, so the two events can arrive in either order.
    it 'keeps each hop of a redirect as its own entry with its own status and duration' do
      recorder = started_recorder
      recorder.navigated('https://example.test/start')
      request_sent('r1', 'GET', 'https://example.test/start', started_ms)
      request_sent('r1', 'GET', 'https://example.test/', started_ms + 1, hop: 1)
      bidi.emit('network.responseCompleted', 'redirectCount' => 0, 'timestamp' => started_ms + 1,
                                             'request' => { 'request' => 'r1' }, 'response' => { 'status' => 302 })
      bidi.emit('network.responseCompleted', 'redirectCount' => 1, 'timestamp' => started_ms + 206,
                                             'request' => { 'request' => 'r1' }, 'response' => { 'status' => 200 })

      expect(kept(recorder)['network'].map { |entry| entry.values_at('url', 'status', 'duration_ms') }).to eq(
        [['https://example.test/start', 302, 1], ['https://example.test/', 200, 205]]
      )
    end

    it 'drops one malformed BiDi event, warns once and keeps tracing' do
      recorder = started_recorder
      bidi.emit('network.beforeRequestSent', 'request' => 'string', 'timestamp' => started_ms)
      bidi.emit('network.responseCompleted', 'request' => { 'request' => 'bad', 'timings' => 'string' },
                                             'response' => 'string', 'timestamp' => started_ms)
      bidi.emit('log.entryAdded', 'level' => 'info', 'text' => 'bad', 'timestamp' => started_ms, 'stackTrace' => 'string')
      request_sent('r1', 'GET', 'https://example.test/ok', started_ms)
      bidi.emit('network.responseCompleted', 'request' => { 'request' => 'r1' }, 'timestamp' => started_ms + 5,
                                             'response' => { 'status' => 200 })
      bidi.emit('log.entryAdded', 'level' => 'info', 'text' => 'good', 'timestamp' => started_ms)
      trace = kept(recorder)

      expect(trace['network'].map { |entry| [entry['url'], entry['status']] }).to include(['https://example.test/ok', 200])
      expect(trace['console'].map { |entry| entry['text'] }).to include('good')
      expect(TraceHelper.enabled?).to be(true)
      expect(warnings.size).to eq(1)
      expect(warnings.first).to match(/dropped a malformed BiDi .* event/)
    end

    it 'records capabilities network/console false and warns once when subscribe raises' do
      bidi.failure = Selenium::WebDriver::Error::WebDriverError.new('no such frame')
      traces = Array.new(2) do
        recorder = started_recorder
        recorder.navigated('https://example.test/login')
        kept(recorder)
      end

      expect(traces.map { |trace| trace['capabilities'] }).to all(include('network' => false, 'console' => false))
      expect(traces.map { |trace| trace['steps'].first['screenshot'] }).to eq(%w[steps/0001.png steps/0001.png])
      expect(warnings).to eq(["[trace] network and console not captured: BiDi subscribe failed: no such frame\n"])
      expect(TraceHelper.enabled?).to be(true)
    end

    it 'names Edge edge, as Selenium reports it MicrosoftEdge, and attaches BiDi to it' do
      allow(capabilities).to receive(:browser_name).and_return('MicrosoftEdge')
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      trace = kept(recorder)

      expect(trace['browser']).to eq('name' => 'edge', 'version' => '131.0.6778.85')
      expect(trace['capabilities']).to include('network' => true, 'console' => true)
      expect(warnings).to eq([])
    end

    it 'records network/console false and warns once for a browser without BiDi' do
      allow(capabilities).to receive(:browser_name).and_return('Safari')
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      trace = kept(recorder)

      expect(trace['capabilities']).to include('network' => false, 'console' => false)
      expect(bidi.subscribed).to eq([])
      expect(warnings).to eq(["[trace] network and console not captured: Safari has no WebDriver BiDi\n"])
    end

    it 'takes a JPEG through BiDi and a PNG without it' do
      recorder = started_recorder
      recorder.navigated('https://example.test/login')
      path = recorder.stop(keep: true, test: failed_test)

      expect(Zip::File.open(path) { |zip| zip.read('steps/0001.jpg') }).to eq(jpeg)
      expect(bidi.commands).to eq([['browsingContext.captureScreenshot',
                                    { context: 'context-1', origin: 'viewport', format: { type: 'image/jpeg', quality: 0.7 } }]])
      expect(TraceHelper::Screenshot.take(driver, bidi: true)).to eq([jpeg, 'jpg'])
      expect(TraceHelper::Screenshot.take(driver, bidi: false)).to eq([png, 'png'])
      bidi.screenshot = Selenium::WebDriver::Error::WebDriverError.new('unsupported operation')
      expect(TraceHelper::Screenshot.take(driver, bidi: true)).to eq([png, 'png'])
    end

    it 'keeps every network entry when callbacks arrive from many threads at once' do
      recorder = started_recorder
      Array.new(8) do |thread|
        Thread.new do
          25.times { |request| recorder.network_event({ method: 'GET', url: "https://example.test/#{thread}/#{request}" }) }
        end
      end.each(&:join)

      expect(kept(recorder)['network'].size).to eq(200)
    end

    it 'is true for chrome, edge and firefox only' do
      expect(%w[chrome edge MicrosoftEdge firefox safari ie].map { |browser| TraceHelper.bidi?(browser) })
        .to eq([true, true, true, true, false, false])
    end

    context 'with TRACE=off' do
      let(:env) { { 'TRACE' => 'off' } }

      it 'is false for every browser, and gives no listener' do
        expect(%w[chrome edge firefox].map { |browser| TraceHelper.bidi?(browser) }).to eq([false, false, false])
        expect(TraceHelper.listener).to be_nil
      end
    end
  end

  # The rendered driver_helper.rb with its fan-out listener and BiDi option, loaded next to
  # the rendered video_helper.rb and the trace_helper.rb loaded above.
  describe 'the driver helper' do
    let(:host) { Object.new.extend(DriverHelper) }
    let(:calls) { [] }
    let(:video_listener) do
      seen = calls
      Class.new(Selenium::WebDriver::Support::AbstractEventListener) do
        define_method(:after_navigate_to) { |url, _driver| seen << [:video, url] }
        define_method(:after_click) { |_element, _driver| seen << %i[video click] }
      end.new
    end
    let(:trace_feature) { File.realpath(File.join(project_dir, 'trace_helper.rb')) }

    def load_driver_helper
      generator = HelpersGenerator.new(%w[selenium rspec proj])
      %w[driver_helper video_helper].each do |name|
        source = File.read(File.expand_path("../../lib/generators/templates/helpers/#{name}.tt", __dir__))
        File.write(File.join(project_dir, "#{name}.rb"), ERB.new(source, trim_mode: '-').result(generator.instance_eval { binding }))
      end
      $LOADED_FEATURES << trace_feature
      load File.join(project_dir, 'driver_helper.rb')
    end

    def write_config(browser)
      config = { 'browser' => browser, 'browser_arguments' => { browser => [] }, 'trace' => trace_config }
      File.write(File.join(project_dir, 'config', 'config.yml'), config.to_yaml)
    end

    def options_for(browser)
      stub_const("Selenium::WebDriver::#{browser.capitalize}::Options", Class.new do
        attr_accessor :web_socket_url

        def add_argument(_argument); end
      end)
      write_config(browser)
      host.instance_variable_set(:@config, YAML.load_file('config/config.yml'))
      host.send(:create_webdriver_options)
    end

    def created_arguments
      write_config('chrome')
      allow(host).to receive(:create_webdriver_options).and_return(:options)
      allow(Selenium::WebDriver).to receive(:for) { |_browser, **arguments| arguments }
      host.send(:create_driver)
    end

    before { load_driver_helper }

    after do
      %i[DriverHelper VideoHelper].each { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
      $LOADED_FEATURES.delete(trace_feature)
    end

    it 'fans navigation out to both video and trace listeners' do
      allow(VideoHelper).to receive(:listener).and_return(video_listener)
      allow(VideoHelper).to receive(:alert_open?).and_return(false)
      listener = created_arguments[:listener]
      recorder = started_recorder
      listener.after_navigate_to('https://example.test/login', driver)
      listener.after_navigate_back(driver)
      listener.after_click(:element, driver)

      expect(listener).to be_a(Selenium::WebDriver::Support::AbstractEventListener)
      expect(calls).to eq([[:video, 'https://example.test/login'], %i[video click]])
      expect(kept(recorder)['steps'].map { |step| step.values_at('kind', 'url') })
        .to eq([['navigate', 'https://example.test/login'], ['navigate', 'https://example.test/login']])
    end

    context 'with VIDEO=off and TRACE=off' do
      let(:env) { { 'VIDEO' => 'off', 'TRACE' => 'off' } }

      it 'passes no listener at all' do
        expect(created_arguments.keys).to eq([:options])
      end

      it 'does not set web_socket_url' do
        expect(options_for('chrome').web_socket_url).to be_nil
      end
    end

    it 'sets web_socket_url only for chrome, edge and firefox and not with TRACE=off' do
      expect(%w[chrome edge firefox safari].map { |browser| options_for(browser).web_socket_url }).to eq([true, true, true, nil])
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/VerifiedDoubles, RSpec/ExpectOutput, RSpec/MultipleExpectations, RSpec/ExampleLength
