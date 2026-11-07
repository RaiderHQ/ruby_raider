# frozen_string_literal: true

require_relative '../../../lib/generators/helper_generator'
require_relative '../spec_helper'

describe HelpersGenerator do
  shared_examples 'creates common helpers' do |name|
    it 'never creates an allure helper file' do
      expect(File).not_to exist("#{name}/helpers/allure_helper.rb")
    end
  end

  shared_examples 'creates a session state helper' do |name|
    it 'creates a session state helper file' do
      expect(File).to exist("#{name}/helpers/session_state.rb")
    end
  end

  shared_examples 'skips the session state helper' do |name|
    it 'does not create a session state helper file' do
      expect(File).not_to exist("#{name}/helpers/session_state.rb")
    end
  end

  shared_examples 'creates selenium helpers' do |name|
    it 'creates a driver helper file' do
      expect(File).to exist("#{name}/helpers/driver_helper.rb")
    end
  end

  shared_examples 'has no wait helper' do |name|
    it 'creates neither the wait helper nor the element wrapper, and no Ruby file mentions them' do
      expect(File).not_to exist("#{name}/helpers/wait_helper.rb")
      expect(File).not_to exist("#{name}/helpers/raider_element.rb")
      files = Dir.glob("#{name}/{helpers,page_objects,spec,config}/**/*.rb")
      expect(files).not_to be_empty
      mentions = files.select { |file| File.read(file).match?(/WaitHelper|RaiderElement/) }
      expect(mentions).to eq([])
    end
  end

  shared_examples 'creates the trace helper' do |name|
    it 'creates the trace helper' do
      expect(File).to exist("#{name}/helpers/trace_helper.rb")
    end
  end

  shared_examples 'skips the trace helper' do |name|
    it 'does not create the trace helper' do
      expect(File).not_to exist("#{name}/helpers/trace_helper.rb")
    end
  end

  shared_examples 'creates the network helper' do |name|
    it 'creates the network helper' do
      expect(File).to exist("#{name}/helpers/network_helper.rb")
    end
  end

  shared_examples 'creates the screenshot helper' do |name|
    it 'creates the screenshot helper' do
      expect(File).to exist("#{name}/helpers/screenshot_helper.rb")
    end
  end

  shared_examples 'skips the screenshot helper' do |name|
    it 'does not create the screenshot helper' do
      expect(File).not_to exist("#{name}/helpers/screenshot_helper.rb")
    end
  end

  shared_examples 'skips the network helper' do |name|
    it 'does not create the network helper' do
      expect(File).not_to exist("#{name}/helpers/network_helper.rb")
    end
  end

  shared_examples 'creates rspec helpers' do |name|
    it 'creates a spec helper file' do
      expect(File).to exist("#{name}/helpers/spec_helper.rb")
    end
  end

  shared_examples 'creates cross platform helpers' do |name|
    it 'creates an appium helper file' do
      expect(File).to exist("#{name}/helpers/appium_helper.rb")
    end
  end

  shared_examples 'creates the gesture helper' do |name|
    it 'creates a gesture helper with swipe, scroll and scroll_to only' do
      content = File.read("#{name}/helpers/gesture_helper.rb")
      expect(content).to include('def swipe(').and include('def scroll(').and include('def scroll_to(')
      expect(content).to include('module GestureHelper')
      expect(content).not_to match(/hover|drag_and_drop/)
    end
  end

  shared_examples 'skips the gesture helper' do |name|
    it 'does not create a gesture helper' do
      expect(File).not_to exist("#{name}/helpers/gesture_helper.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'skips the gesture helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates a session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'has no wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'has no wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates the gesture helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'has no wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates the gesture helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'has no wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates the gesture helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates cross platform helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
  end

  describe 'without example tests' do
    %w[rspec].product(%w[selenium ios cross_platform]).each do |framework, automation|
      context "with #{framework} and #{automation}" do
        let(:name) { ensure_project(framework:, automation:, examples: false) }

        include_examples 'has no wait helper', "#{framework}_#{automation}"

        it "#{automation == 'selenium' ? 'skips' : 'creates'} the gesture helper" do
          expect(File.exist?("#{name}/helpers/gesture_helper.rb")).to eq(automation != 'selenium')
        end

        it "#{automation == 'selenium' ? 'creates' : 'skips'} the trace helper" do
          expect(File.exist?("#{name}/helpers/trace_helper.rb")).to eq(automation == 'selenium')
        end

        it "#{automation == 'selenium' ? 'creates' : 'skips'} the network helper" do
          expect(File.exist?("#{name}/helpers/network_helper.rb")).to eq(automation == 'selenium')
        end

        it "#{automation == 'selenium' ? 'creates' : 'skips'} the screenshot helper" do
          expect(File.exist?("#{name}/helpers/screenshot_helper.rb")).to eq(automation == 'selenium')
        end
      end
    end

    it 'keeps the session state for web' do
      name = ensure_project(framework: 'rspec', automation: 'selenium', examples: false)
      expect(File).to exist("#{name}/helpers/session_state.rb")
    end
  end
end
