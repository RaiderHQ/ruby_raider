# frozen_string_literal: true

require_relative 'content_helper'

describe 'Generated Readme content' do
  FRAMEWORKS.product(AUTOMATION_TYPES).each do |framework, automation|
    context "with #{framework} and #{automation}, the Video replay section" do
      subject(:section) { readme[/^### Video replay\n.*?(?=^##)/m]&.gsub(/\s+/, ' ') }

      let(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }
      let(:web) { %w[selenium watir].include?(automation) }

      it 'exists and covers the defaults, VIDEO=off, the install commands and the cache' do
        expect(section).not_to be_nil
        expect(section).to include('only for failing tests', 'VIDEO=off', 'raider u video install',
                                   'raider u video status', '~/.cache/raider', 'RAIDER_FFMPEG_PATH',
                                   'RAIDER_CACHE_DIR', 'raider-results/attachments/')
      end

      it 'says that video needs RAIDER_FFMPEG_PATH until the ffmpeg release is published' do
        expect(section).to include('ffmpeg-7.1', 'not published yet')
      end

      it 'names the right video format and how to turn video off for this project' do
        if web
          expect(section).to include('video.webm', 'raider u video off', 'raider u video on', 'video:')
        elsif %w[android ios].include?(automation)
          expect(section).to include('video.mp4', 'raider u video off', 'creates `config/config.yml`')
          expect(section).not_to include('no `config/config.yml`')
        else
          expect(section).to include('video.mp4', 'raider u video off')
        end
      end

      it 'says where mobile recording needs ffmpeg and how long it records' do
        limits = { 'ios' => ['1800 s'], 'android' => ['180 s'], 'cross_platform' => ['1800 s', '180 s'] }
        if web
          expect(section).not_to include('Appium server host')
        else
          expect(section).to include('`ffmpeg` on the Appium server host', 'iOS', 'longer than 180 s',
                                     'time_limit', *limits.fetch(automation))
          expect(section).not_to include('do not use ffmpeg')
        end
      end

      it 'lists the known limits of web recording' do
        if web
          expect(section).to include('after each page load, click and text change', 'next frame',
                                     'one recorded driver per process')
        else
          expect(section).not_to include('next frame')
        end
      end
    end
  end

  AUTOMATION_TYPES.each do |automation|
    context "with rspec and #{automation}" do
      subject(:readme) { read_generated("#{FrameworkIndex::RSPEC}_#{automation}", 'Readme.md') }

      it 'has a Reporting section' do
        expect(readme).to include('## Reporting')
      end

      it 'documents local results, upload settings and the raider_reporter README' do
        expect(readme).to include('raider-results/', 'RAIDER_TOKEN', 'RAIDER_ENDPOINT',
                                  'https://github.com/RaiderHQ/raider_reporter')
      end

      it 'explains quarantine in CI' do
        expect(readme).to include('### Quarantine', 'RAIDER_QUARANTINE', 'raider-reporter exec')
      end

      it 'explains the quality gate' do
        expect(readme).to include('### Quality gate', 'RAIDER_GATE=1', 'Gate page', 'raider/gate',
                                  'raider-reporter gate', 'raider-gate', 'exits 1 when the gate fails',
                                  '2 when it gets no verdict', 'RAIDER_GATE_TIMEOUT', 'RAIDER_SHARD_TOTAL',
                                  'RAIDER_SHARD_INDEX')
      end

      it 'points to the local HTML report' do
        expect(readme).to include('raider-results/index.html')
        expect(readme).not_to match(/allure/i)
      end
    end

    context "with cucumber and #{automation}" do
      subject(:readme) { read_generated("#{FrameworkIndex::CUCUMBER}_#{automation}", 'Readme.md') }

      it 'has a Reporting section' do
        expect(readme).to include('## Reporting')
      end

      it 'documents local results, upload settings, plugin mode and the raider_reporter README' do
        expect(readme).to include('raider-results/', 'RAIDER_TOKEN', 'RAIDER_ENDPOINT', 'features/support/env.rb',
                                  'https://github.com/RaiderHQ/raider_reporter')
      end

      it 'explains quarantine in CI' do
        expect(readme).to include('### Quarantine', 'RAIDER_QUARANTINE', 'raider-reporter exec')
      end

      it 'explains the quality gate' do
        expect(readme).to include('### Quality gate', 'RAIDER_GATE=1', 'Gate page', 'raider/gate',
                                  'raider-reporter gate', 'raider-gate', 'exits 1 when the gate fails',
                                  '2 when it gets no verdict', 'RAIDER_GATE_TIMEOUT', 'RAIDER_SHARD_TOTAL',
                                  'RAIDER_SHARD_INDEX')
      end

      it 'does not mention Allure' do
        expect(readme).not_to match(/allure/i)
      end
    end
  end

  FRAMEWORKS.product(AUTOMATION_TYPES).each do |framework, automation|
    context "with #{framework} and #{automation}, the login reuse section" do
      subject(:readme) { read_generated("#{framework}_#{automation}", 'Readme.md') }

      if %w[selenium watir].include?(automation)
        it 'documents the tags, other roles, max_age, the env switch and the secrets warning' do
          section = readme[/^## Reusing the login\n.*?(?=^##)/m].gsub(/\s+/, ' ')
          expect(section).to include('`:logged_in`', '`@logged_in`', "SessionState.new(driver, name: 'admin')",
                                     'browser.driver', 'login_state', 'max_age', 'RAIDER_LOGIN_STATE=off',
                                     'RAIDER_LOGIN_STATE=refresh', '.raider/auth/', 'git-ignored',
                                     'live session tokens', 'must not be committed, cached or uploaded')
        end

        it 'is its own ## section, straight after the Quality gate and before any CI section' do
          heading = readme.index("\n## Reusing the login\n")
          gate = readme.index("\n### Quality gate\n")
          expect(gate).to be < heading
          expect(readme[(gate + 1)...heading]).not_to match(/\n##/)
          expect(readme[(heading + 1)..][/\n## .*/]).to be_nil.or match(/\A\n## (CI|Azure Pipelines)\z/)
        end
      else
        it 'does not mention login reuse' do
          expect(readme).not_to include('Reusing the login', 'RAIDER_LOGIN_STATE', '.raider/auth/')
        end
      end
    end
  end
end
