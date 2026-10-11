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

      let(:hook) { env[/^\s*After do.*\z/m] }
      let(:quit_call) { automation == 'watir' ? 'browser.quit' : 'driver.quit' }

      it 'takes the screenshot only for failed scenarios, inside the guard block' do
        guarded = /if scenario\.failed\?\n\s+Dir\.mktmpdir do \|temp_folder\|\n(?<body>.*?)\n\s+end\n\s+end\n\s+ensure/m
        expect(hook.match(guarded)[:body]).to include(screenshot_call)
      end

      it 'uses a fixed file name in the tmpdir, never the scenario name' do
        expect(env).to include("screenshot_path = File.join(temp_folder, 'screenshot.png')")
        expect(hook).not_to include('scenario.name')
      end

      it 'quits the driver in an ensure that follows the begin' do
        quit = %w[android ios cross_platform].include?(automation) ? 'driver.quit_driver' : quit_call
        expect(hook).to match(/^\s*After do \|scenario\|\n\s+begin\n.*\n\s+ensure\n\s+#{Regexp.escape(quit)}\n\s+end\nend/m)
      end

      it 'attaches the screenshot path before quitting the driver' do
        attach = "RaiderReporter.attach('screenshot', screenshot_path, type: :png)"
        expect(env).to include(attach)
        expect(env.index(screenshot_call)).to be < env.index(attach)
        expect(env.index(attach)).to be < env.index(/driver\.quit|browser\.quit/, env.index(attach))
      end

      it 'does not generate the allure helper' do
        expect(File).not_to exist(File.join(project_name, 'helpers/allure_helper.rb'))
      end

      it 'does not mention Allure in any generated file' do
        files = Dir.glob("#{project_name}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }
        expect(files.select { |f| File.read(f).match?(/allure/i) }).to be_empty
      end

      it 'does not create an allure-results folder' do
        expect(File).not_to exist(File.join(project_name, 'allure-results'))
      end
    end
  end
end
