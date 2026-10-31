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
      let(:hook) { env[/^\s*After do.*\z/m] }
      let(:quit_call) { automation == 'watir' ? 'browser.quit' : 'driver.quit' }

      it 'activates the reporter by requiring raider_reporter/cucumber' do
        expect(env).to include("require 'raider_reporter/cucumber'")
      end

      it 'does not reference the allure helper' do
        expect(env).not_to match(/AllureHelper|allure_helper/)
      end

      it 'takes the screenshot only for failed scenarios, inside the guard block' do
        guarded = /if scenario\.failed\?\n\s+Dir\.mktmpdir do \|temp_folder\|\n(?<body>.*?)\n\s+end\n\s+end\nensure/m
        expect(hook.match(guarded)[:body]).to include(screenshot_call)
      end

      it 'uses a fixed file name in the tmpdir, never the scenario name' do
        expect(env).to include("screenshot_path = File.join(temp_folder, 'screenshot.png')")
        expect(hook).not_to include('scenario.name')
      end

      it 'quits the driver in an ensure of the After block, without a redundant begin' do
        quit = %w[android ios cross_platform].include?(automation) ? 'driver.quit_driver' : quit_call
        expect(hook).to match(/^\s*After do \|scenario\|\n.*\n^ensure\n.*\n\s+#{Regexp.escape(quit)}\nend/m)
        expect(hook).not_to match(/^\s+begin$/)
      end

      it 'attaches the screenshot path before quitting the driver' do
        attach = "RaiderReporter.attach('screenshot', screenshot_path, type: :png)"
        expect(env).to include(attach)
        expect(env.index(screenshot_call)).to be < env.index(attach)
        expect(env.index(attach)).to be < env.index(/driver\.quit|browser\.quit/, env.index(attach))
      end

      context 'with video recording' do
        target = automation == 'watir' ? 'browser' : 'driver'
        video_type = %w[selenium watir].include?(automation) ? ':webm' : ':mp4'

        it 'requires video_helper' do
          expect(env).to include("require_relative '../../helpers/video_helper'")
        end

        it 'starts the recorder in Before' do
          expect(env[/^Before do.*?^end$/m]).to include("@video_recorder = VideoHelper.recorder_for(#{target})", '@video_recorder.start')
        end

        it 'stops with keep: scenario.failed? before quitting, attaches the path and cleans up in the ensure' do
          expect(hook).to include('video_path = @video_recorder&.stop(keep: scenario.failed?)')
          expect(hook).to include("RaiderReporter.attach('video', video_path, type: #{video_type}) if video_path")
          expect(hook.index('@video_recorder&.stop')).to be < hook.index("RaiderReporter.attach('video'")
          expect(hook.index("RaiderReporter.attach('video'")).to be < hook.index(/^ensure/)
          expect(hook.index(/^ensure/)).to be < hook.index('@video_recorder&.cleanup')
        end
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

describe 'Cucumber login reuse wiring' do
  { 'selenium' => 'driver', 'watir' => 'browser.driver' }.each do |automation, target|
    context "with cucumber and #{automation}" do
      let(:env) { read_generated("#{FrameworkIndex::CUCUMBER}_#{automation}", 'features/support/env.rb') }

      it 'requires session_state' do
        expect(env).to include("require_relative '../../helpers/session_state'")
      end

      it "reuses the saved login in Before('@logged_in'), defined after the plain Before" do
        expect(env).to include("Before('@logged_in') do", "SessionState.new(#{target}).reuse(",
                               "UserFactory.for('registered user')")
        expect(env.index("Before('@logged_in')")).to be > env.index(/^Before do/)
      end
    end
  end

  %w[android ios cross_platform].each do |automation|
    it "does not mention session_state with cucumber and #{automation}" do
      env = read_generated("#{FrameworkIndex::CUCUMBER}_#{automation}", 'features/support/env.rb')
      expect(env).not_to include('session_state')
    end
  end
end
