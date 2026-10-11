# frozen_string_literal: true

require_relative 'content_helper'

describe 'Cucumber raider_reporter wiring' do
  screenshot_calls = {
    'selenium' => 'driver.save_screenshot(screenshot_path)',
    'watir' => 'browser.screenshot.save(screenshot_path)'
  }

  AUTOMATION_TYPES.each do |automation|
    context "with cucumber and #{automation}" do
      let(:project_name) { "#{FrameworkIndex::CUCUMBER}_#{automation}" }
      let(:env) { read_generated(project_name, 'features/support/env.rb') }
      let(:screenshot_call) { screenshot_calls.fetch(automation, 'driver.screenshot(screenshot_path)') }

      it 'activates the reporter by requiring raider_reporter/cucumber' do
        expect(env).to include("require 'raider_reporter/cucumber'")
      end

      it 'does not reference the allure helper' do
        expect(env).not_to match(/AllureHelper|allure_helper/)
      end

      it 'takes the screenshot only for failed scenarios' do
        expect(env).to match(/if scenario\.failed\?.*#{Regexp.escape(screenshot_call)}/m)
      end

      it 'attaches the screenshot path before quitting the driver' do
        attach = "RaiderReporter.attach('screenshot', screenshot_path, type: :png)"
        expect(env).to include(attach)
        expect(env.index(screenshot_call)).to be < env.index(attach)
        expect(env.index(attach)).to be < env.index(/driver\.quit|browser\.quit/)
      end

      it 'does not generate the allure helper' do
        expect(File).not_to exist(File.join(project_name, 'helpers/allure_helper.rb'))
      end

      it 'does not mention Allure in any generated file' do
        files = Dir.glob("#{project_name}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }
        # .github/ workflows are reworked in R2.
        files.reject! { |f| f.start_with?("#{project_name}/.github/") }
        expect(files.select { |f| File.read(f).match?(/allure/i) }).to be_empty
      end

      it 'does not create an allure-results folder' do
        expect(File).not_to exist(File.join(project_name, 'allure-results'))
      end
    end
  end
end
