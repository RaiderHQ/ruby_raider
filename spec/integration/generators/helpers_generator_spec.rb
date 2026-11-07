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

  shared_examples 'creates the wait helper' do |name|
    it 'creates the wait helper and the element wrapper' do
      expect(File).to exist("#{name}/helpers/wait_helper.rb")
      expect(File).to exist("#{name}/helpers/raider_element.rb")
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

  context 'with rspec and selenium' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates a session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates the wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'skips the session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates the wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'skips the session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates the wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with rspec and appium cross platform' do
    include_examples 'creates common helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the trace helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the network helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the screenshot helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'skips the session state helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates selenium helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates the wait helper', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates rspec helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
    include_examples 'creates cross platform helpers', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CROSS_PLATFORM}"
  end

  describe 'without example tests' do
    %w[rspec].product(%w[selenium ios cross_platform]).each do |framework, automation|
      context "with #{framework} and #{automation}" do
        let(:name) { ensure_project(framework:, automation:, examples: false) }

        it 'creates the wait helper and RaiderElement' do
          expect(File).to exist("#{name}/helpers/wait_helper.rb")
          expect(File).to exist("#{name}/helpers/raider_element.rb")
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
