# frozen_string_literal: true

require_relative 'content_helper'

SYNTAX_WEB_AUTOMATIONS = %w[selenium watir].freeze
SYNTAX_ALL_FRAMEWORKS = %w[cucumber rspec].freeze

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

        login_reuse_files = %w[helpers/session_state.rb]
        login_reuse_files += if framework == 'rspec'
                               %w[helpers/spec_helper.rb]
                             else
                               %w[features/support/env.rb features/step_definitions/login_steps.rb]
                             end
        # The glob above runs at load time, before the projects exist, so new helpers are listed here.
        login_reuse_files += %w[helpers/wait_helper.rb helpers/raider_element.rb] if automation == 'selenium'

        login_reuse_files.each do |relative|
          it "#{relative} is generated as valid Ruby with frozen_string_literal" do
            content = File.read(File.join(project_name, relative))
            expect(content).to have_valid_ruby_syntax
            expect(content).to have_frozen_string_literal
          end
        end
      end
    end
  end
end
