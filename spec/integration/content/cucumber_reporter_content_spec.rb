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

      if automation == 'selenium'
        context 'with trace recording' do
          it 'requires trace_helper' do
            expect(env).to include("require_relative '../../helpers/trace_helper'")
          end

          it 'counts attempts per scenario location and starts the trace recorder after the video recorder' do
            before_hook = env[/^Before do.*?^end$/m]
            expect(env).to match(/^TRACE_ATTEMPTS = Hash\.new\(0\)$/)
            expect(before_hook).to include('TRACE_ATTEMPTS[scenario.location.to_s] += 1', '@trace_recorder = TraceHelper.recorder_for(driver)')
            expect(before_hook).to match(/^Before do \|scenario\|$/)
            expect(before_hook.index('@video_recorder.start')).to be < before_hook.index('@trace_recorder = TraceHelper')
            expect(before_hook).to match(/if defined\?\(TraceHelper\)\n(.*\n)*.*@trace_recorder = TraceHelper/)
          end

          it 'stops with keep: TraceHelper.keep_all? || scenario.failed? before the video, attaches it and cleans up before quitting' do
            expect(hook).to include('TraceHelper.keep_all? || scenario.failed?', 'error: scenario.exception', 'attempt: @trace_attempt')
            expect(hook).to include("RaiderReporter.attach('trace', trace_path, type: :trace, attempt: @trace_attempt) if trace_path")
            order = [hook.index('@trace_recorder&.stop'), hook.index('@video_recorder&.stop'), hook.index("RaiderReporter.attach('trace'"),
                     hook.index(/^ensure/), hook.index('@trace_recorder&.cleanup'), hook.index('@video_recorder&.cleanup'), hook.index('driver.quit')]
            expect(order).to all(be_an(Integer)).and eq(order.compact.sort)
          end

          it 'survives a Before that raised before the trace init, and a failing plugin setup or handler' do
            expect(hook).to include('@trace_test&.merge(')
            expect(hook).not_to include('@trace_test.merge(')
            plugin = env[/^InstallPlugin do.*?^end$/m]
            expect(plugin.scan('rescue StandardError => e').size).to eq(3)
            expect(plugin.index('AstLookup.new')).to be > plugin.index("begin\n")
            expect(plugin).to include('TraceHelper.warn_once("Gherkin step groups unavailable')
          end

          it 'turns tracing off with TraceHelper.disable! when a step group handler raises' do
            plugin = env[/^InstallPlugin do.*?^end$/m]
            expect(plugin.scan(/TraceHelper\.disable!\("step groups failed: \#\{e\.message\}"\) if defined\?\(TraceHelper\)/).size).to eq(2)
            expect(plugin).not_to include('tracing disabled')
          end

          it 'records each Gherkin step as a group through the InstallPlugin step events, skipping hooks' do
            plugin = env[/^InstallPlugin do.*?^end$/m]
            expect(plugin).to include('config.on_event(:test_step_started)', 'config.on_event(:test_step_finished)', 'next if event.test_step.hook?')
            expect(plugin).to include('TraceHelper.active_recorder&.step_started', 'TraceHelper.active_recorder&.step_finished')
            expect(plugin).to include('defined?(TraceHelper)')
          end
        end
      else
        it 'has no trace wiring' do
          expect(env).not_to match(/trace/i)
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
