# frozen_string_literal: true

require 'chunky_png'
require 'erb'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/generators/helper_generator'

# Renders screenshot_helper.tt for a selenium/rspec project and loads it.
module ScreenshotHelperRenderer
  TEMPLATE = File.expand_path('../../lib/generators/templates/helpers/screenshot_helper.tt', __dir__)

  def render_and_load_screenshot_helper
    generator = HelpersGenerator.new(%w[selenium rspec proj])
    rendered = ERB.new(File.read(TEMPLATE), trim_mode: '-').result(generator.instance_eval { binding })
    Dir.mktmpdir('screenshot-helper') do |dir|
      path = File.join(dir, 'screenshot_helper.rb')
      File.write(path, rendered)
      Object.send(:remove_const, :ScreenshotHelper) if Object.const_defined?(:ScreenshotHelper)
      load path
    end
  end
end

RSpec.describe 'ScreenshotHelper' do
  include ScreenshotHelperRenderer

  before { render_and_load_screenshot_helper }

  it 'raises Mismatch as a failed expectation' do
    expect(ScreenshotHelper::Mismatch.ancestors).to include(RSpec::Expectations::ExpectationNotMetError)
  end

  describe '.config' do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    it 'uses the defaults without a config file' do
      expect(ScreenshotHelper.config).to eq(threshold: 0.2, max_diff_pixels: 0, max_diff_ratio: nil)
    end

    it 'uses the defaults when config.yml has no screenshots block' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "browser: chrome\n")
      expect(ScreenshotHelper.config).to eq(threshold: 0.2, max_diff_pixels: 0, max_diff_ratio: nil)
    end

    it 'reads the screenshots block over the defaults' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "screenshots:\n  threshold: 0.1\n  max_diff_ratio: 0.001\n")
      expect(ScreenshotHelper.config).to eq(threshold: 0.1, max_diff_pixels: 0, max_diff_ratio: 0.001)
    end
  end

  describe 'ScreenshotHelper::Diff' do
    def png(width, height, color = ChunkyPNG::Color::WHITE)
      image = ChunkyPNG::Image.new(width, height, color)
      yield image if block_given?
      image.to_blob
    end

    def compare(expected, actual, threshold: 0.2)
      ScreenshotHelper::Diff.compare(expected, actual, threshold: threshold)
    end

    it 'finds no difference between identical images' do
      result = compare(png(10, 10), png(10, 10))
      expect([result.diff_pixels, result.diff_ratio, result.size_changed?]).to eq([0, 0.0, false])
    end

    it 'counts one changed pixel and its share of the image' do
      changed = png(10, 10) { |image| image[3, 4] = ChunkyPNG::Color::BLACK }
      result = compare(png(10, 10), changed)
      expect([result.diff_pixels, result.diff_ratio]).to eq([1, 0.01])
    end

    it 'lets the threshold decide whether a small shade counts' do
      grey = ChunkyPNG::Color.rgb(0x80, 0x80, 0x80)
      slightly = ChunkyPNG::Color.rgb(0x82, 0x82, 0x82)
      expected = png(4, 4, grey)
      actual = png(4, 4, grey) { |image| image[0, 0] = slightly }
      expect(compare(expected, actual, threshold: 0.2).diff_pixels).to eq(0)
      expect(compare(expected, actual, threshold: 0).diff_pixels).to eq(1)
    end

    it 'reports a size change and draws both images side by side' do
      result = compare(png(10, 10), png(10, 12))
      diff = ChunkyPNG::Image.from_blob(result.diff_png)
      expect([result.size_changed?, result.expected_size, result.actual_size, result.diff_ratio])
        .to eq([true, [10, 10], [10, 12], 0.0])
      expect([diff.width, diff.height]).to eq([20, 12])
    end

    it 'blends transparent pixels over white before comparing' do
      transparent = png(5, 5, ChunkyPNG::Color::TRANSPARENT)
      expect(compare(transparent, png(5, 5), threshold: 0).diff_pixels).to eq(0)
    end

    it 'paints a changed pixel red and the rest grey in the diff image' do
      changed = png(10, 10) { |image| image[3, 4] = ChunkyPNG::Color.rgb(0, 0, 0) }
      diff = ChunkyPNG::Image.from_blob(compare(png(10, 10), changed).diff_png)
      expect(diff[3, 4]).to eq(ChunkyPNG::Color.rgb(255, 0, 0))
      expect(ChunkyPNG::Color.r(diff[0, 0])).to eq(ChunkyPNG::Color.g(diff[0, 0]))
      expect(diff[0, 0]).not_to eq(diff[3, 4])
    end

    it 'raises Unreadable for bytes that are not a PNG' do
      expect { compare('garbage', png(2, 2)) }.to raise_error(ScreenshotHelper::Diff::Unreadable)
      expect { compare(png(2, 2), 'garbage') }.to raise_error(ScreenshotHelper::Diff::Unreadable)
    end
  end

  describe 'ScreenshotHelper::Baseline' do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    it 'accepts plain and nested names' do
      %w[home checkout/summary a-b_c].each do |name|
        expect { ScreenshotHelper::Baseline.validate_name!(name) }.not_to raise_error
      end
    end

    it 'rejects names that could leave the baseline folder or are malformed' do
      ['../x', '/x', 'a//b', 'a.png', '', 'a/', 'a' * 101, nil].each do |name|
        expect { ScreenshotHelper::Baseline.validate_name!(name) }.to raise_error(ArgumentError)
      end
    end

    it 'accepts a name of exactly 100 characters' do
      expect { ScreenshotHelper::Baseline.validate_name!('a' * 100) }.not_to raise_error
    end

    it 'refuses a bad name before anything is written' do
      expect { ScreenshotHelper::Baseline.new('../x', browser: 'chrome') }.to raise_error(ArgumentError)
      expect(Dir.children('.')).to be_empty
    end

    it 'builds a relative path under the browser folder' do
      baseline = ScreenshotHelper::Baseline.new('checkout/summary', browser: 'edge')
      expect(baseline.path).to eq('screenshots/baselines/edge/checkout/summary.png')
    end

    it 'writes atomically, creating folders and leaving no temp file' do
      baseline = ScreenshotHelper::Baseline.new('a/b', browser: 'chrome')
      expect(baseline.exist?).to be(false)
      baseline.write('png bytes')
      expect(baseline.exist?).to be(true)
      expect(baseline.read).to eq('png bytes')
      expect(Dir.children('screenshots/baselines/chrome/a')).to eq(['b.png'])
    end

    it 'resolves the path against root' do
      Dir.mktmpdir do |root|
        ScreenshotHelper::Baseline.new('x', browser: 'chrome', root: root).write('1')
        expect(File.read(File.join(root, 'screenshots/baselines/chrome/x.png'))).to eq('1')
      end
    end
  end

  describe '.browser' do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    def browser_from(value)
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "browser: #{value}\n")
      ScreenshotHelper.browser
    end

    it 'names the folder after the configured browser, without the microsoft prefix' do
      expect(%w[chrome MicrosoftEdge edge Firefox].map { |value| browser_from(value) })
        .to eq(%w[chrome edge edge firefox])
    end

    it 'falls back to chrome without a config' do
      expect(ScreenshotHelper.browser).to eq('chrome')
    end
  end

  describe '.update? and .ci?' do
    around do |example|
      saved = ENV.to_h.slice('SCREENSHOTS', 'CI')
      example.run
    ensure
      %w[SCREENSHOTS CI].each { |key| ENV.delete(key) }
      ENV.update(saved)
    end

    it 'updates only when SCREENSHOTS=update, in any case' do
      ENV.delete('SCREENSHOTS')
      expect(ScreenshotHelper.update?).to be(false)
      ENV['SCREENSHOTS'] = 'Update'
      expect(ScreenshotHelper.update?).to be(true)
      ENV['SCREENSHOTS'] = 'no'
      expect(ScreenshotHelper.update?).to be(false)
    end

    it 'detects CI through the reporter, or CI in the environment' do
      hide_const('RaiderReporter')
      ENV.delete('CI')
      expect(ScreenshotHelper.ci?).to be(false)
      ENV['CI'] = 'true'
      expect(ScreenshotHelper.ci?).to be(true)
    end

    it 'uses the reporter detector when it is there' do
      ENV.delete('CI')
      detector = instance_double('detector', ci: { provider: 'github' })
      stub_const('RaiderReporter::CiDetector', class_double('RaiderReporter::CiDetector', new: detector))
      expect(ScreenshotHelper.ci?).to be(true)
    end

    it 'falls back to the environment when the detector fails' do
      ENV['CI'] = '1'
      stub_const('RaiderReporter::CiDetector', Class.new { define_method(:initialize) { raise 'boom' } })
      expect(ScreenshotHelper.ci?).to be(true)
    end
  end

  describe '.decide' do
    def decide(exists:, matched:, on_ci: false, update: false)
      allow(ScreenshotHelper).to receive_messages(ci?: on_ci, update?: update)
      ScreenshotHelper.decide(baseline_exists: exists, matched: matched)
    end

    it 'creates a missing baseline locally' do
      expect(decide(exists: false, matched: false)).to eq(:created)
    end

    it 'fails a missing baseline on CI unless asked to update' do
      expect(decide(exists: false, matched: false, on_ci: true)).to eq(:missing_on_ci)
      expect(decide(exists: false, matched: false, on_ci: true, update: true)).to eq(:created)
    end

    it 'updates a mismatch only when asked to' do
      expect(decide(exists: true, matched: false, update: true)).to eq(:updated)
      expect(decide(exists: true, matched: false)).to eq(:failed)
    end

    it 'passes a match, update or not' do
      expect(decide(exists: true, matched: true)).to eq(:passed)
      expect(decide(exists: true, matched: true, update: true)).to eq(:passed)
    end
  end

  describe '#match_screenshot' do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    before do
      ScreenshotHelper.reset
      allow(ScreenshotHelper).to receive_messages(ci?: false, update?: false)
    end

    # Answers like a Selenium driver: queued PNGs (the last one repeats), scripts logged as events.
    let(:driver_class) do
      Class.new do
        attr_reader :events, :captures

        def initialize(*pngs, ratio: 2, failing: false)
          @pngs = pngs
          @ratio = ratio
          @failing = failing
          @events = []
          @captures = 0
        end

        def screenshot_as(_format)
          @events << :capture
          raise 'capture failed' if @failing

          @captures += 1
          @pngs[[@captures - 1, @pngs.length - 1].min]
        end

        def execute_async_script(_script)
          @events << :fonts
        end

        def execute_script(script, *_args)
          @events << :add_style if script.include?('appendChild')
          @events << :remove_style if script.include?('.remove()')
          @events << :scroll if script.include?('scrollIntoView')
          raise 'no ratio' if script.include?('devicePixelRatio') && @ratio.nil?

          @ratio if script.include?('devicePixelRatio')
        end
      end
    end

    def png(width = 10, height = 10, color = ChunkyPNG::Color::WHITE)
      image = ChunkyPNG::Image.new(width, height, color)
      yield image if block_given?
      image.to_blob
    end

    def different
      png { |image| image[1, 1] = ChunkyPNG::Color::BLACK }
    end

    def host_for(driver)
      Class.new do
        include ScreenshotHelper

        attr_reader :driver

        def initialize(driver)
          @driver = driver
        end
      end.new(driver)
    end

    def baseline_path(name = 'home', browser = 'chrome')
      "screenshots/baselines/#{browser}/#{name}.png"
    end

    def store_baseline(bytes, name = 'home')
      FileUtils.mkdir_p(File.dirname(baseline_path(name)))
      File.binwrite(baseline_path(name), bytes)
    end

    it 'passes when the page matches the baseline' do
      store_baseline(png)
      driver = driver_class.new(png)
      expect(host_for(driver).match_screenshot('home')).to be(true)
      expect(driver.captures).to eq(1)
    end

    it 'retries after a difference and passes once the page matches' do
      store_baseline(png)
      driver = driver_class.new(different, png)
      expect(host_for(driver).match_screenshot('home', timeout: 5)).to be(true)
      expect(driver.captures).to eq(2)
    end

    it 'raises Mismatch after the timeout, naming the baseline, the pixels and the limits' do
      store_baseline(png)
      driver = driver_class.new(different)
      expect { host_for(driver).match_screenshot('home', timeout: 0.3) }
        .to raise_error(ScreenshotHelper::Mismatch) { |error|
          expect(error.message).to include(baseline_path, '1 pixel (1.00%) differ', 'threshold 0.2', '0 pixels')
        }
      expect(driver.captures).to be >= 2
    end

    it 'honours max_diff_pixels and max_diff_ratio' do
      store_baseline(png)
      expect(host_for(driver_class.new(different)).match_screenshot('home', max_diff_pixels: 1, timeout: 0)).to be(true)
      ScreenshotHelper.reset
      expect(host_for(driver_class.new(different)).match_screenshot('home', max_diff_ratio: 0.05, timeout: 0)).to be(true)
    end

    it 'reads the defaults from config.yml' do
      FileUtils.mkdir_p('config')
      File.write('config/config.yml', "screenshots:\n  max_diff_pixels: 5\n")
      store_baseline(png)
      expect(host_for(driver_class.new(different)).match_screenshot('home', timeout: 0)).to be(true)
    end

    it 'fails a size change naming both sizes and the device pixel ratio, without comparing pixels' do
      store_baseline(png(20, 10))
      driver = driver_class.new(png(40, 20), ratio: 2)
      expect { host_for(driver).match_screenshot('home', timeout: 0) }
        .to raise_error(ScreenshotHelper::Mismatch, /size changed: baseline 20x10, now 40x20 \(device pixel ratio 2\)/)
    end

    it 'leaves the device pixel ratio out when it cannot be read' do
      store_baseline(png(20, 10))
      expect { host_for(driver_class.new(png(40, 20), ratio: nil)).match_screenshot('home', timeout: 0) }
        .to raise_error(ScreenshotHelper::Mismatch) { |error|
          expect(error.message).to include('size changed: baseline 20x10, now 40x20')
          expect(error.message).not_to include('device pixel ratio')
        }
    end

    it 'writes a missing baseline outside CI and passes' do
      expect(host_for(driver_class.new(png)).match_screenshot('home')).to be(true)
      expect(File.binread(baseline_path)).to eq(png)
    end

    it 'fails a missing baseline on CI and writes nothing' do
      allow(ScreenshotHelper).to receive(:ci?).and_return(true)
      driver = driver_class.new(png)
      expect { host_for(driver).match_screenshot('home') }.to raise_error(
        ScreenshotHelper::Mismatch,
        "no baseline for 'home' on chrome; run it locally or with SCREENSHOTS=update and commit the file"
      )
      expect(File.exist?('screenshots')).to be(false)
    end

    it 'writes a missing baseline on CI when asked to update' do
      allow(ScreenshotHelper).to receive_messages(ci?: true, update?: true)
      expect(host_for(driver_class.new(png)).match_screenshot('home')).to be(true)
      expect(File.exist?(baseline_path)).to be(true)
    end

    it 'rewrites a differing baseline when asked to update' do
      allow(ScreenshotHelper).to receive(:update?).and_return(true)
      store_baseline(png)
      expect(host_for(driver_class.new(different)).match_screenshot('home', timeout: 0)).to be(true)
      expect(File.binread(baseline_path)).to eq(different)
    end

    it 'fails an unreadable baseline and leaves the file alone' do
      store_baseline('not a png')
      expect { host_for(driver_class.new(png)).match_screenshot('home', timeout: 0) }
        .to raise_error(ScreenshotHelper::Mismatch, /baseline .*home\.png is not a readable PNG/)
      expect(File.binread(baseline_path)).to eq('not a png')
    end

    it 'replaces an unreadable baseline when asked to update' do
      allow(ScreenshotHelper).to receive(:update?).and_return(true)
      store_baseline('not a png')
      expect(host_for(driver_class.new(png)).match_screenshot('home')).to be(true)
      expect(File.binread(baseline_path)).to eq(png)
    end

    it 'refuses a bad name before any capture' do
      driver = driver_class.new(png)
      expect { host_for(driver).match_screenshot('../x') }.to raise_error(ArgumentError)
      expect(driver.events).to be_empty
    end

    it 'refuses the same name twice in one test until reset' do
      store_baseline(png)
      host = host_for(driver_class.new(png))
      host.match_screenshot('home')
      expect { host.match_screenshot('home') }.to raise_error(ArgumentError, /already used/)
      ScreenshotHelper.reset
      expect(host.match_screenshot('home')).to be(true)
    end

    it 'compares an element, scrolled into view' do
      store_baseline(png)
      element = instance_double('element')
      allow(element).to receive(:screenshot_as).with(:png).and_return(png)
      driver = driver_class.new(different)
      expect(host_for(driver).match_screenshot('home', element: element)).to be(true)
      expect(driver.captures).to eq(0)
      expect(driver.events).to include(:scroll)
    end

    it 'adds the settle stylesheet before the capture and removes it after' do
      store_baseline(png)
      driver = driver_class.new(png)
      host_for(driver).match_screenshot('home')
      expect(driver.events.reject { |event| event == :scroll })
        .to eq(%i[fonts add_style capture remove_style])
    end

    it 'removes the settle stylesheet when the capture raises' do
      store_baseline(png)
      driver = driver_class.new(png, failing: true)
      expect { host_for(driver).match_screenshot('home') }.to raise_error(RuntimeError, 'capture failed')
      expect(driver.events.last).to eq(:remove_style)
    end
  end

  describe 'trace step' do
    around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

    let(:seen) { [] }
    let(:driver_class) do
      Class.new do
        def initialize(png)
          @png = png
        end

        def screenshot_as(_format)
          @png
        end

        def execute_async_script(_script); end

        def execute_script(*); end
      end
    end
    let(:host_class) do
      Class.new do
        include ScreenshotHelper
        attr_reader :driver

        def initialize(driver)
          @driver = driver
        end
      end
    end
    let(:white) { ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color::WHITE).to_blob }
    let(:black) { ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color::BLACK).to_blob }

    before do
      ScreenshotHelper.reset
      allow(ScreenshotHelper).to receive_messages(ci?: false, update?: false)
      seen = self.seen
      wait_helper = Module.new
      wait_helper.define_singleton_method(:report) { |hook, **details| seen.replace([hook, details]) }
      stub_const('WaitHelper', wait_helper)
    end

    def match(png, name: 'home', **options)
      host_class.new(driver_class.new(png)).match_screenshot(name, timeout: 0, **options)
    end

    def store(bytes)
      FileUtils.mkdir_p('screenshots/baselines/chrome')
      File.binwrite('screenshots/baselines/chrome/home.png', bytes)
    end

    it 'reports a created comparison as passed with the actual PNG' do
      match(white)
      expect(seen).to eq([:screenshot_compared, { name: 'home', status: :passed, png: white }])
    end

    it 'reports a passed comparison once' do
      store(white)
      match(white)
      expect(seen).to eq([:screenshot_compared, { name: 'home', status: :passed, png: white }])
    end

    it 'reports a failed comparison before the Mismatch is raised, with the last actual PNG' do
      store(white)
      expect { match(black) }.to raise_error(ScreenshotHelper::Mismatch)
      expect(seen).to eq([:screenshot_compared, { name: 'home', status: :failed, png: black }])
    end

    it 'reports an updated comparison as passed' do
      store(white)
      allow(ScreenshotHelper).to receive(:update?).and_return(true)
      match(black)
      expect(seen).to eq([:screenshot_compared, { name: 'home', status: :passed, png: black }])
    end

    it 'reports nothing when no screenshot was taken' do
      allow(ScreenshotHelper).to receive(:ci?).and_return(true)
      expect { match(white) }.to raise_error(ScreenshotHelper::Mismatch, /no baseline/)
      expect(seen).to be_empty
    end

    it 'reports nothing without WaitHelper' do
      hide_const('WaitHelper')
      expect(match(white)).to be(true)
    end
  end

  describe 'WaitHelper.report' do
    # Only the observer part of the rendered wait helper, on a module of its own.
    def wait_helper_observer
      generator = HelpersGenerator.new(%w[selenium rspec proj])
      template = File.expand_path('../../lib/generators/templates/helpers/wait_helper.tt', __dir__)
      rendered = ERB.new(File.read(template), trim_mode: '-').result(generator.instance_eval { binding })
      code = rendered[%r{^\s*attr_accessor :observer.*?# rubocop:enable Style/StderrPuts}m]
      Module.new.tap { |mod| mod.singleton_class.class_eval(code) }
    end

    it 'passes the hook to an observer that has it and leaves one without it alone, silently' do
      helper = wait_helper_observer
      seen = []
      helper.observer = Class.new { define_method(:screenshot_compared) { |**details| seen << details } }.new
      helper.report(:screenshot_compared, name: 'a', status: :passed, png: 'x')
      expect(seen).to eq([{ name: 'a', status: :passed, png: 'x' }])

      other = Object.new
      helper.observer = other
      expect { helper.report(:screenshot_compared, name: 'a', status: :passed, png: 'x') }.not_to output.to_stderr
      expect(helper.observer).to be(other)
    end
  end

  describe 'ScreenshotHelper::Report' do
    let(:attached) { [] }
    let(:recorded) { [] }
    let(:reporter) do
      files = attached
      records = recorded
      Module.new do
        define_singleton_method(:attach) do |name, path, **options|
          files << [name, path, options, File.exist?(path), File.binread(path)]
        end
        define_singleton_method(:comparison) { |**fields| records << fields }
      end
    end
    let(:diff_result) do
      ScreenshotHelper::Diff::Result.new(1, 0.01, [10, 10], [10, 10], 'diff-bytes')
    end
    let(:options) { { threshold: 0.2, max_diff_pixels: 0, max_diff_ratio: nil } }

    def report(status, result: diff_result, images: {})
      ScreenshotHelper::Report.call(name: 'home', status: status, baseline: 'screenshots/baselines/chrome/home.png',
                                    result: result, options: options, images: images)
    end

    it 'attaches the three images of a failed comparison, then records it' do
      stub_const('RaiderReporter', reporter)
      report(:failed, images: { expected: 'e', actual: 'a', diff: 'd' })
      expect(attached.map { |file| file.first(3) }).to eq(
        [['comparison:home:expected', attached[0][1], { type: :png }],
         ['comparison:home:actual', attached[1][1], { type: :png }],
         ['comparison:home:diff', attached[2][1], { type: :png }]]
      )
      expect(attached.map { |file| file[4] }).to eq(%w[e a d])
      expect(recorded).to eq(
        [{ name: 'home', status: :failed, baseline: 'screenshots/baselines/chrome/home.png', diff_pixels: 1,
           diff_ratio: 0.01, threshold: 0.2, max_diff_pixels: 0, max_diff_ratio: nil,
           expected_size: [10, 10], actual_size: [10, 10] }]
      )
    end

    it 'attaches only the actual image of a created comparison, with zero differences' do
      stub_const('RaiderReporter', reporter)
      report(:created, result: nil, images: { actual: ChunkyPNG::Image.new(7, 5).to_blob })
      expect(attached.map(&:first)).to eq(['comparison:home:actual'])
      expect(recorded.first).to include(status: :created, diff_pixels: 0, diff_ratio: 0.0, expected_size: nil,
                                        actual_size: [7, 5])
    end

    it 'gives an updated comparison without a diff result the size of the actual image' do
      stub_const('RaiderReporter', reporter)
      report(:updated, result: nil, images: { actual: ChunkyPNG::Image.new(3, 4).to_blob })
      expect(recorded.first).to include(status: :updated, expected_size: nil, actual_size: [3, 4])
    end

    it 'keeps the real sizes of an updated comparison that had a diff result' do
      stub_const('RaiderReporter', reporter)
      report(:updated, images: { actual: ChunkyPNG::Image.new(3, 4).to_blob })
      expect(recorded.first).to include(expected_size: [10, 10], actual_size: [10, 10])
    end

    it 'attaches nothing for a passed comparison but still records it' do
      stub_const('RaiderReporter', reporter)
      report(:passed)
      expect(attached).to be_empty
      expect(recorded.map { |fields| fields[:status] }).to eq([:passed])
    end

    it 'removes the temp files afterwards' do
      stub_const('RaiderReporter', reporter)
      report(:failed, images: { expected: 'e', actual: 'a', diff: 'd' })
      expect(attached.map { |file| file[3] }).to all(be(true))
      expect(attached.map { |file| File.exist?(file[1]) }).to all(be(false))
    end

    it 'attaches only and warns once when the reporter has no comparison method' do
      old = Module.new
      files = attached
      old.define_singleton_method(:attach) { |name, path, **_| files << [name, path] }
      stub_const('RaiderReporter', old)
      expect { 2.times { report(:failed, images: { actual: 'a' }) } }
        .to output(/raider_reporter.*comparison/m).to_stderr
      expect(attached.length).to eq(2)
    end

    it 'does nothing without raider_reporter' do
      hide_const('RaiderReporter')
      expect { report(:failed, images: { actual: 'a' }) }.not_to raise_error
    end

    def host_with(png)
      driver = Struct.new(:png) do
        def screenshot_as(_format)
          png
        end

        def execute_async_script(_script); end

        def execute_script(*); end
      end.new(png)
      Class.new { include ScreenshotHelper }.new.tap { |host| host.define_singleton_method(:driver) { driver } }
    end

    it 'is called by match_screenshot before it raises' do
      stub_const('RaiderReporter', reporter)
      ScreenshotHelper.reset
      allow(ScreenshotHelper).to receive_messages(ci?: false, update?: false)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('screenshots/baselines/chrome')
          File.binwrite('screenshots/baselines/chrome/home.png', ChunkyPNG::Image.new(4, 4, ChunkyPNG::Color::WHITE).to_blob)
          black = ChunkyPNG::Image.new(4, 4, ChunkyPNG::Color::BLACK).to_blob
          host = host_with(black)
          expect { host.match_screenshot('home', timeout: 0) }.to raise_error(ScreenshotHelper::Mismatch)
        end
      end
      expect(attached.map(&:first)).to eq(%w[comparison:home:expected comparison:home:actual comparison:home:diff])
      expect(recorded.first).to include(status: :failed, diff_pixels: 16)
    end
  end
end
