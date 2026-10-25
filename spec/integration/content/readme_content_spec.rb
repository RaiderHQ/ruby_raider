# frozen_string_literal: true

require_relative 'content_helper'

describe 'Generated Readme content' do
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
end
