# frozen_string_literal: true

require_relative 'content_helper'

SYNTAX_WEB_AUTOMATIONS = %w[selenium watir capybara].freeze
SYNTAX_ALL_FRAMEWORKS = %w[cucumber rspec minitest].freeze

describe 'Ruby syntax validation' do
  SYNTAX_ALL_FRAMEWORKS.each do |framework|
    SYNTAX_WEB_AUTOMATIONS.each do |automation|
      context "with #{framework} and #{automation}" do
        project_name = "#{framework}_#{automation}"

        Dir.glob("#{project_name}/**/*.rb").each do |file|
          relative = file.sub("#{project_name}/", '')

          it "#{relative} has valid Ruby syntax" do
            content = File.read(file)
            expect(content).to have_valid_ruby_syntax
          end

          it "#{relative} has frozen_string_literal" do
            content = File.read(file)
            expect(content).to have_frozen_string_literal
          end
        end
      end
    end
  end
end
