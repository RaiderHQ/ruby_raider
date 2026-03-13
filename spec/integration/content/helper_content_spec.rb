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

  # --- Capybara helper ---

  shared_examples 'valid capybara helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/capybara_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'defines CapybaraHelper module' do
      expect(helper).to match(/module CapybaraHelper/)
    end

    it 'requires capybara' do
      expect(helper).to include("require 'capybara'")
    end

    it 'configures Capybara' do
      expect(helper).to include('Capybara.configure')
    end

    it 'registers Selenium driver' do
      expect(helper).to include('Capybara.register_driver')
    end

    it 'reads from config.yml' do
      expect(helper).to include("YAML.load_file('config/config.yml')")
    end

    it 'does not require watir' do
      expect(helper).not_to include("require 'watir'")
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

  shared_examples 'capybara spec helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/spec_helper.rb') }

    it 'includes Capybara::DSL' do
      expect(helper).to include('include(Capybara::DSL)')
    end

    it 'requires capybara_helper' do
      expect(helper).to include("require_relative 'capybara_helper'")
    end

    it 'calls CapybaraHelper.configure' do
      expect(helper).to include('CapybaraHelper.configure')
    end
  end

  # --- Test helper (Minitest) ---

  shared_examples 'valid test helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/test_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'requires minitest/autorun' do
      expect(helper).to include("require 'minitest/autorun'")
    end

    it 'defines TestHelper module' do
      expect(helper).to match(/module TestHelper/)
    end

    it 'includes TestHelper into Minitest::Test' do
      expect(helper).to include('Minitest::Test.include(TestHelper)')
    end
  end

  shared_examples 'selenium test helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/test_helper.rb') }

    it 'includes DriverHelper' do
      expect(helper).to include('include DriverHelper')
    end

    it 'requires driver_helper' do
      expect(helper).to include("require_relative 'driver_helper'")
    end
  end

  shared_examples 'watir test helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/test_helper.rb') }

    it 'includes BrowserHelper' do
      expect(helper).to include('include BrowserHelper')
    end

    it 'requires browser_helper' do
      expect(helper).to include("require_relative 'browser_helper'")
    end
  end

  shared_examples 'capybara test helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/test_helper.rb') }

    it 'includes Capybara::DSL' do
      expect(helper).to include('include Capybara::DSL')
    end

    it 'requires capybara_helper' do
      expect(helper).to include("require_relative 'capybara_helper'")
    end

    it 'calls CapybaraHelper.configure' do
      expect(helper).to include('CapybaraHelper.configure')
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

    it 'defines VideoHelper module' do
      expect(helper).to match(/module VideoHelper/)
    end

    it 'defines recorder_for method' do
      expect(helper).to include('def recorder_for')
    end

    it 'defines CdpRecorder class' do
      expect(helper).to include('class CdpRecorder')
    end

    it 'defines ScreenCaptureRecorder class' do
      expect(helper).to include('class ScreenCaptureRecorder')
    end

    it 'defines NullRecorder class' do
      expect(helper).to include('class NullRecorder')
    end

    it 'reads config from YAML' do
      expect(helper).to include('YAML.load_file')
    end
  end

  shared_examples 'mobile video helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/video_helper.rb') }

    it 'defines AppiumRecorder class' do
      expect(helper).to include('class AppiumRecorder')
    end
  end

  shared_examples 'web-only video helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/video_helper.rb') }

    it 'does not include AppiumRecorder' do
      expect(helper).not_to include('class AppiumRecorder')
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

  # --- Debug helper ---

  shared_examples 'valid debug helper' do |project_name|
    subject(:helper) { read_generated(project_name, 'helpers/debug_helper.rb') }

    it 'has frozen_string_literal' do
      expect(helper).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper).to have_valid_ruby_syntax
    end

    it 'defines DebugHelper module' do
      expect(helper).to match(/module DebugHelper/)
    end

    it 'defines enabled? method' do
      expect(helper).to include('def enabled?')
    end

    it 'defines capture_failure_diagnostics method' do
      expect(helper).to include('def capture_failure_diagnostics')
    end

    it 'defines ActionLogger class' do
      expect(helper).to include('class ActionLogger')
    end

    it 'defines NullActionLogger class' do
      expect(helper).to include('class NullActionLogger')
    end

    it 'reads config from YAML' do
      expect(helper).to include('YAML.load_file')
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
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
    it_behaves_like 'valid spec helper', name
    it_behaves_like 'watir spec helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  context 'with rspec and capybara' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::CAPYBARA}"
    it_behaves_like 'valid capybara helper', name
    it_behaves_like 'valid spec helper', name
    it_behaves_like 'capybara spec helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  # --- Minitest + automation contexts ---

  context 'with minitest and selenium' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid driver helper', name
    it_behaves_like 'selenium driver helper', name
    it_behaves_like 'valid test helper', name
    it_behaves_like 'selenium test helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  context 'with minitest and watir' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
    it_behaves_like 'valid test helper', name
    it_behaves_like 'watir test helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  context 'with minitest and capybara' do
    name = "#{FrameworkIndex::MINITEST}_#{AutomationIndex::CAPYBARA}"
    it_behaves_like 'valid capybara helper', name
    it_behaves_like 'valid test helper', name
    it_behaves_like 'capybara test helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  # --- Cucumber + automation contexts (no spec_helper/test_helper) ---

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    it_behaves_like 'valid driver helper', name
    it_behaves_like 'selenium driver helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    it_behaves_like 'valid browser helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  context 'with cucumber and capybara' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CAPYBARA}"
    it_behaves_like 'valid capybara helper', name
    it_behaves_like 'valid allure helper', name
    it_behaves_like 'valid video helper', name
    it_behaves_like 'web-only video helper', name
    it_behaves_like 'valid debug helper', name
  end

  # --- Mobile contexts (with AppiumRecorder) ---

  context 'with cucumber and appium android' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
    it_behaves_like 'valid video helper', name
    it_behaves_like 'mobile video helper', name
  end

  context 'with rspec and appium ios' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
    it_behaves_like 'valid video helper', name
    it_behaves_like 'mobile video helper', name
  end
end
