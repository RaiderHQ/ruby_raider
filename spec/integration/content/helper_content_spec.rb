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

    it 'requires allure_helper' do
      expect(helper).to include("require_relative 'allure_helper'")
    end
  end

  shared_examples 'raider reporter spec helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'requires raider_reporter/rspec' do
      expect(helper).to include("require 'raider_reporter/rspec'")
    end

    it 'does not replace the formatter' do
      expect(helper).not_to match(/config\.formatter\s*=/)
    end

    it 'adds the allure formatter' do
      expect(helper).to include('config.add_formatter(AllureHelper.formatter)')
    end

    it 'screenshots only on failure' do
      expect(helper.scan('AllureHelper.add_screenshot').size).to eq(1)
      expect(helper).to match(/if example\.exception\n(?:(?!\bend\b).*\n)*?.*AllureHelper\.add_screenshot/)
      expect(helper).not_to match(/^ {6}Dir\.mktmpdir/)
    end

    it 'attaches the screenshot to raider by path' do
      expect(helper).to include("RaiderReporter.attach('screenshot', screenshot_path, type: :png)")
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

  # --- Allure helper ---

  shared_examples 'valid allure helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/allure_helper.rb') }

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'defines AllureHelper' do
      expect(helper).to match(/AllureHelper|module AllureHelper|class AllureHelper/)
    end
  end

  # --- RSpec + automation contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid driver helper', name
    it_behaves_like 'selenium driver helper', name
    it_behaves_like 'valid spec helper', name
    it_behaves_like 'selenium spec helper', name
    it_behaves_like 'valid allure helper', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
    it_behaves_like 'valid spec helper', name
    it_behaves_like 'watir spec helper', name
    it_behaves_like 'valid allure helper', name
  end

  # --- Cucumber + automation contexts (no spec_helper/test_helper) ---

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid driver helper', name
    it_behaves_like 'selenium driver helper', name
    it_behaves_like 'valid allure helper', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
    it_behaves_like 'valid allure helper', name
  end

  # --- Mobile contexts (with AppiumRecorder) ---

  context 'with cucumber and appium android' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"

  end

  context 'with rspec and appium ios' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"

  end

  # --- Raider reporter wiring (every rspec automation) ---

  SCREENSHOT_CALLS = {
    'selenium' => 'driver.save_screenshot(screenshot_path)',
    'watir' => 'browser.screenshot.save(screenshot_path)',
    'android' => 'driver.screenshot(screenshot_path)',
    'ios' => 'driver.screenshot(screenshot_path)',
    'cross_platform' => 'driver.screenshot(screenshot_path)'
  }.freeze

  AUTOMATION_TYPES.each do |automation|
    context "with rspec and #{automation} raider reporter wiring" do
      name = "#{FrameworkIndex::RSPEC}_#{automation}"
      it_behaves_like 'raider reporter spec helper', name

      it 'takes the screenshot with the automation call into a path' do
        expect(read_generated(name, 'helpers/spec_helper.rb')).to include(SCREENSHOT_CALLS.fetch(automation))
      end
    end

    context "with cucumber and #{automation}" do
      it 'has no raider reporter wiring' do
        project = "#{FrameworkIndex::CUCUMBER}_#{automation}"
        files = Dir.glob("#{project}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }
        expect(files.select { |f| File.read(f).match?(/raider_reporter|RaiderReporter/) }).to be_empty
      end
    end
  end
end
