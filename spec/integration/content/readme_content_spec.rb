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

      it 'says Allure is still produced' do
        expect(readme).to match(/Allure/)
      end
    end

    context "with cucumber and #{automation}" do
      it 'has no Reporting section' do
        readme = read_generated("#{FrameworkIndex::CUCUMBER}_#{automation}", 'Readme.md')
        expect(readme).not_to include('RAIDER_TOKEN')
      end
    end
  end
end
