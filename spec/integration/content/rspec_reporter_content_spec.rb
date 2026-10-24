# frozen_string_literal: true

require_relative 'content_helper'

describe 'RSpec projects without Allure' do
  AUTOMATION_TYPES.each do |automation|
    context "with rspec and #{automation}" do
      let(:project_name) { "#{FrameworkIndex::RSPEC}_#{automation}" }

      it 'does not mention Allure in any generated file' do
        files = Dir.glob("#{project_name}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }
        files = files.reject { |f| File.binread(f, 512).include?("\x00") }
        expect(files.select { |f| File.read(f).match?(/allure/i) }).to be_empty
      end

      it 'does not generate the allure helper or the allure-results folder' do
        expect(File).not_to exist(File.join(project_name, 'helpers/allure_helper.rb'))
        expect(File).not_to exist(File.join(project_name, 'allure-results'))
      end

      it 'pins raider_reporter 0.8' do
        expect(read_generated(project_name, 'Gemfile')).to include("gem 'raider_reporter', '~> 0.8'")
      end
    end
  end
end
