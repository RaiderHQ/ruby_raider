# frozen_string_literal: true

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

  it 'has a match_screenshot that is not implemented yet' do
    host = Class.new { include ScreenshotHelper }.new
    expect { host.match_screenshot('home') }.to raise_error(NotImplementedError)
  end
end
