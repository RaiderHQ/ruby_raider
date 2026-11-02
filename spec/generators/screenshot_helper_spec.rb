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

  it 'has a match_screenshot that is not implemented yet' do
    host = Class.new { include ScreenshotHelper }.new
    expect { host.match_screenshot('home') }.to raise_error(NotImplementedError)
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
end
