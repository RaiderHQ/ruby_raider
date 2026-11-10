# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
require 'rspec'
require_relative '../../lib/ruby_raider/runtime/show_browser'

# The prepend is process-wide, so every case that loads the runtime and looks at the Options classes runs
# in its own ruby with an explicit RAIDER_SHOW_BROWSER. This process only checks the pure helpers.
RSpec.describe Raider::ShowBrowser do # rubocop:disable RSpec/FilePath
  lib = File.expand_path('../../lib', __dir__)

  # Loads the runtime the way a project's driver_helper does, then reports the real Options classes
  probe = <<~RUBY
    require 'json'
    require 'ruby_raider/runtime'
    filter = Raider::ShowBrowser::Filter
    Raider::ShowBrowser.install(ENV) if ARGV.include?('again')
    report = %w[Chrome Edge Firefox].to_h do |browser|
      klass = Selenium::WebDriver.const_get(browser)::Options
      built = klass.new(args: ['--headless', 'start-maximized', '--headless=new', '-headless'])
      %w[--headless --headless=old -headless window-size=800,600 --headlessly headless].each { |arg| built.add_argument(arg) }
      set = klass.new
      set.args = ['--headless', 'set']
      keyed = klass.new('args' => ['-headless', 'keyed'])
      args = ->(options) { options.as_json.fetch(klass::KEY).fetch('args') }
      [browser, { 'prepended' => klass.ancestors.count(filter), 'built' => args.call(built), 'set' => args.call(set),
                  'keyed' => keyed.options['args'] }]
    end
    puts JSON.generate(report)
  RUBY

  define_method(:probe) do |value, *argv|
    out, err, status = Open3.capture3({ 'RAIDER_SHOW_BROWSER' => value, 'HEADLESS' => nil }, RbConfig.ruby, '-I', lib, '-e', probe, *argv)
    raise "probe failed: #{err}" unless status.success?

    JSON.parse(out)
  end

  context 'with RAIDER_SHOW_BROWSER=1' do
    let(:report) { probe('1') }

    it 'prepends the filter once to the Chrome, Edge and Firefox options' do
      expect(report.transform_values { |browser| browser['prepended'] }).to eq('Chrome' => 1, 'Edge' => 1, 'Firefox' => 1)
    end

    it 'prepends it once when installed again' do
      expect(probe('1', 'again').transform_values { |browser| browser['prepended'] }).to eq('Chrome' => 1, 'Edge' => 1, 'Firefox' => 1)
    end

    it 'drops --headless, --headless=* and -headless from args: and add_argument and keeps every other argument' do
      expected = %w[start-maximized window-size=800,600 --headlessly headless]
      expect(report.transform_values { |browser| browser['built'] }).to eq('Chrome' => expected, 'Edge' => expected, 'Firefox' => expected)
    end

    it 'drops them from args= and from a string args key' do
      expect(report.transform_values { |browser| browser.values_at('set', 'keyed') })
        .to eq('Chrome' => [%w[set], %w[keyed]], 'Edge' => [%w[set], %w[keyed]], 'Firefox' => [%w[set], %w[keyed]])
    end
  end

  [nil, '', '0', 'true', '1 ', 'yes'].each do |value|
    it "prepends nothing and keeps --headless when RAIDER_SHOW_BROWSER is #{value.inspect}" do
      report = probe(value)
      expect(report.transform_values { |browser| [browser['prepended'], browser['built'].first, browser['set']] })
        .to eq('Chrome' => [0, '--headless', %w[--headless set]], 'Edge' => [0, '--headless', %w[--headless set]],
               'Firefox' => [0, '--headless', %w[--headless set]])
    end
  end

  describe '.headless?' do
    it 'matches only the headless switches' do
      args = ['--headless', '--headless=new', '--headless=', '-headless', 'headless', '--headlessly', '-headless=new', ' --headless', :'--headless', nil]
      expect(args.select { |arg| described_class.headless?(arg) }).to eq(['--headless', '--headless=new', '--headless=', '-headless'])
    end
  end

  describe '.without_headless' do
    it 'returns a new array and leaves the given one untouched' do
      given = %w[--headless keep].freeze
      expect(described_class.without_headless(given)).to eq(%w[keep])
    end

    it 'passes anything that is not an array through' do
      expect([nil, '--headless'].map { |value| described_class.without_headless(value) }).to eq([nil, '--headless'])
    end
  end

  describe '.install' do
    it 'installs nothing unless the value is exactly 1' do
      expect([{}, { 'RAIDER_SHOW_BROWSER' => 'true' }].map { |env| described_class.install(env) }).to eq([[], []])
    end
  end
end
