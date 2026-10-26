# frozen_string_literal: true

require_relative 'content_helper'

describe 'Helper file content' do
  # --- Driver helper ---

  shared_examples 'valid driver helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/driver_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'defines DriverHelper module' do
      expect(helper).to match(/module DriverHelper/)
    end

    it 'defines driver method' do
      expect(helper).to match(/def driver/)
    end

    it 'requires yaml' do
      expect(helper).to include("require 'yaml'")
    end
  end

  shared_examples 'selenium driver helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/driver_helper.rb') }

    it 'requires selenium-webdriver' do
      expect(helper).to include("require 'selenium-webdriver'")
    end

    it 'does not require watir' do
      expect(helper).not_to include("require 'watir'")
    end

    it 'does not reference Capybara' do
      expect(helper).not_to include('Capybara')
    end
  end

  # --- Browser helper ---

  shared_examples 'valid browser helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/browser_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'defines BrowserHelper module' do
      expect(helper).to match(/module BrowserHelper/)
    end

    it 'requires watir' do
      expect(helper).to include("require 'watir'")
    end

    it 'defines browser method' do
      expect(helper).to match(/def browser/)
    end

    it 'creates Watir::Browser' do
      expect(helper).to include('Watir::Browser.new')
    end

    it 'does not require selenium-webdriver' do
      expect(helper).not_to include("require 'selenium-webdriver'")
    end
  end

  # --- Spec helper ---

  shared_examples 'valid spec helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'requires rspec' do
      expect(helper).to include("require 'rspec'")
    end

    it 'defines SpecHelper module' do
      expect(helper).to match(/module SpecHelper/)
    end

    it 'configures RSpec' do
      expect(helper).to include('RSpec.configure')
    end
  end

  shared_examples 'raider reporter spec helper' do |project_name, screenshot_call|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'requires raider_reporter/rspec' do
      expect(helper).to include("require 'raider_reporter/rspec'")
    end

    it 'adds the raider formatter in spec_helper so a command-line --format cannot drop it' do
      expect(helper).to include('config.add_formatter(RaiderReporter::RSpec::Formatter)')
    end

    it 'does not replace the formatter' do
      expect(helper).not_to match(/config\.formatter\s*=/)
    end

    it 'screenshots only on failure' do
      lines = helper.lines
      start = lines.index { |line| line.include?('if example.exception') }
      expect(start).not_to be_nil
      indent = lines[start][/\A */].size
      body = lines[(start + 1)..].take_while { |line| line.strip.empty? || line[/\A */].size > indent }
      guarded = body.join

      expect(guarded).to include('RaiderReporter.attach', screenshot_call)
      expect(helper).not_to include('AllureHelper')
      expect(helper).not_to match(/screenshot\s*=/)
      expect(lines.select { |line| line.include?(screenshot_call) }.size).to eq(1)
    end

    it 'attaches the screenshot to raider by path' do
      expect(helper).to include("RaiderReporter.attach('screenshot', screenshot_path, type: :png)")
    end
  end

  shared_examples 'video spec helper wiring' do |project_name, recorder_target, video_type|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    let(:before_hook) { helper[/config\.before\(:each\) do.*?^    end$/m] }
    let(:after_hook) { helper[/config\.after\(:each\).*\z/m] }

    it 'requires video_helper' do
      expect(helper).to include("require_relative 'video_helper'")
    end

    it 'starts a recorder in before(:each), after the viewport resize or driver start' do
      start = "@video_recorder = VideoHelper.recorder_for(#{recorder_target})"
      expect(before_hook).to include(start, '@video_recorder.start')
      setup = before_hook[/driver\.start_driver|\.window\.maximize/]
      expect(before_hook.index(setup)).to be < before_hook.index(start)
      expect(before_hook.index(start)).to be < before_hook.index('@video_recorder.start')
    end

    it 'attaches "video" only when example.exception && VideoHelper.final_attempt?(example)' do
      expect(after_hook).to match(/example\.exception\s*(\?|&&)\s*VideoHelper\.final_attempt\?\(example\)/)
      expect(after_hook).to include("RaiderReporter.attach('video', video_path, type: #{video_type}) if video_path")
    end

    it 'stops the recorder before quitting the driver and cleans up in an ensure' do
      stop = after_hook.index('@video_recorder&.stop(keep: keep_video)')
      attach = after_hook.index("RaiderReporter.attach('video'")
      quit = after_hook.index(/driver\.quit|browser\.quit/)
      cleanup = after_hook.index('@video_recorder&.cleanup')
      expect(stop).to be < quit
      expect(attach).to be < cleanup
      expect(after_hook.index("\n    ensure\n")).to be < cleanup
    end

    it 'keeps the screenshot attachment' do
      expect(after_hook).to include("RaiderReporter.attach('screenshot', screenshot_path, type: :png)")
    end
  end

  shared_examples 'selenium spec helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'includes DriverHelper' do
      expect(helper).to include('include(DriverHelper)')
    end

    it 'requires driver_helper' do
      expect(helper).to include("require_relative 'driver_helper'")
    end

    it 'maximizes window via driver' do
      expect(helper).to include('driver.manage.window.maximize')
    end
  end

  shared_examples 'watir spec helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'includes BrowserHelper' do
      expect(helper).to include('include(BrowserHelper)')
    end

    it 'requires browser_helper' do
      expect(helper).to include("require_relative 'browser_helper'")
    end

    it 'maximizes window via browser' do
      expect(helper).to include('browser.window.maximize')
    end
  end

  # --- Video helper ---

  shared_examples 'valid video helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/video_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'defines VideoHelper with enabled?, recorder_for and disable!' do
      expect(helper).to match(/module VideoHelper/)
      expect(helper).to match(/def enabled\?/)
      expect(helper).to match(/def recorder_for\(/)
      expect(helper).to match(/def disable!\(/)
    end

    it 'has no ScreenCaptureRecorder and no CdpRecorder' do
      expect(helper).not_to include('ScreenCaptureRecorder')
      expect(helper).not_to include('CdpRecorder')
    end
  end

  shared_examples 'web video helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/video_helper.rb') }

    it 'defines a FrameRecorder and a Selenium FrameListener' do
      expect(helper).to include('class FrameRecorder')
      expect(helper).to include('class FrameListener < Selenium::WebDriver::Support::AbstractEventListener')
    end

    it 'captures only after navigate, click and change_value_of' do
      hooks = helper.scan(/def ((?:after|before)_\w+)/).flatten
      expect(hooks).to contain_exactly('after_navigate_to', 'after_click', 'after_change_value_of')
    end

    it 'encodes WebM with libvpx' do
      expect(helper).to include("'libvpx'", 'video.webm')
    end

    it 'loads ffmpeg lazily from the ruby_raider gem' do
      expect(helper).to include("require 'ruby_raider/ffmpeg'")
      expect(helper).not_to match(/^require 'ruby_raider/)
    end

    it 'has no AppiumRecorder' do
      expect(helper).not_to include('AppiumRecorder')
    end
  end

  shared_examples 'mobile video helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/video_helper.rb') }

    it 'defines an AppiumRecorder writing mp4' do
      expect(helper).to include('class AppiumRecorder', 'start_recording_screen', 'video.mp4')
    end

    it 'has no FrameRecorder or listener' do
      expect(helper).not_to include('FrameRecorder')
      expect(helper).not_to include('AbstractEventListener')
    end

    it 'does not need ffmpeg' do
      expect(helper).not_to include('ffmpeg')
    end
  end

  shared_examples 'video listener wiring' do |project_name, helper_file|
    subject(:helper) { read_generated(project_name, "helpers/#{helper_file}") }

    it 'requires video_helper' do
      expect(helper).to include("require_relative 'video_helper'")
    end

    it 'passes VideoHelper.listener only when it is not nil' do
      expect(helper).to include('VideoHelper.listener')
      expect(helper).to match(/\[:listener\] = listener if listener/)
    end
  end

  context 'with rspec and selenium video' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web video helper', name
    it_behaves_like 'video listener wiring', name, 'driver_helper.rb'
  end

  context 'with cucumber and watir video' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web video helper', name
    it_behaves_like 'video listener wiring', name, 'browser_helper.rb'
  end

  context 'with rspec and ios video' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    it_behaves_like 'valid video helper', name
    it_behaves_like 'mobile video helper', name

    it 'does not wire a listener into the appium driver helper' do
      expect(read_generated(name, 'helpers/driver_helper.rb')).not_to include('listener')
    end
  end

  # --- RSpec + automation contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid driver helper', name
    it_behaves_like 'selenium driver helper', name
    it_behaves_like 'valid spec helper', name
    it_behaves_like 'selenium spec helper', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
    it_behaves_like 'valid spec helper', name
    it_behaves_like 'watir spec helper', name
  end

  # --- Cucumber + automation contexts (no spec_helper/test_helper) ---

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid driver helper', name
    it_behaves_like 'selenium driver helper', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
  end

  # --- Raider reporter wiring (every rspec automation) ---

  AUTOMATION_TYPES.each do |automation|
    context "with rspec and #{automation} raider reporter wiring" do
      name = "#{FrameworkIndex::RSPEC}_#{automation}"
      screenshot_call = {
        'selenium' => 'driver.save_screenshot(screenshot_path)',
        'watir' => 'browser.screenshot.save(screenshot_path)'
      }.fetch(automation, 'driver.screenshot(screenshot_path)')
      it_behaves_like 'raider reporter spec helper', name, screenshot_call
      it_behaves_like 'video spec helper wiring', name, automation == 'watir' ? 'browser' : 'driver',
                      %w[selenium watir].include?(automation) ? ':webm' : ':mp4'
    end

    context "with cucumber and #{automation}" do
      it 'does not generate the allure helper' do
        expect(File).not_to exist("#{FrameworkIndex::CUCUMBER}_#{automation}/helpers/allure_helper.rb")
      end
    end
  end
end
