# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require_relative '../../lib/commands/scaffolding_commands'
require_relative '../../lib/scaffolding/scaffolding'

# Custom matchers (defined inline to avoid pulling in integration spec_helper)
RSpec::Matchers.define :have_frozen_string_literal do
  match { |content| content.include?('# frozen_string_literal: true') }
  failure_message { 'expected file to contain frozen_string_literal magic comment' }
end

RSpec::Matchers.define :have_valid_ruby_syntax do
  match do |content|
    RubyVM::InstructionSequence.compile(content)
    true
  rescue SyntaxError
    false
  end
  failure_message { |_content| "expected valid Ruby syntax but got SyntaxError: #{$ERROR_INFO&.message}" }
end

# End-to-end scaffolding tests that verify the scaffold command creates the right
# files with the right content across all automation × framework combinations.
describe 'Scaffolding E2E' do # rubocop:disable RSpec/DescribeClass

  WEB_AUTOMATIONS = %w[selenium watir].freeze
  TEST_FRAMEWORKS = %w[rspec cucumber].freeze

  def self.scaffold_style(framework)
    case framework
    when 'rspec'    then :spec
    when 'cucumber' then :feature
    end
  end

  # Build a minimal mock project that the scaffolding system can detect.
  def self.build_mock_project(automation, framework) # rubocop:disable Metrics/MethodLength
    dir = File.expand_path("tmp_scaffold_e2e_#{framework}_#{automation}")
    FileUtils.rm_rf(dir)
    FileUtils.mkdir_p("#{dir}/page_objects/pages")
    FileUtils.mkdir_p("#{dir}/page_objects/abstract")
    FileUtils.mkdir_p("#{dir}/page_objects/components")
    FileUtils.mkdir_p("#{dir}/helpers")
    FileUtils.mkdir_p("#{dir}/config")
    FileUtils.mkdir_p("#{dir}/models/data")

    case framework
    when 'rspec'    then FileUtils.mkdir_p("#{dir}/spec")
    when 'cucumber' then FileUtils.mkdir_p("#{dir}/features/step_definitions")
                         FileUtils.mkdir_p("#{dir}/features/support")
    end

    gems = []
    case automation
    when 'selenium'  then gems << "gem 'selenium-webdriver'"
    when 'watir'     then gems << "gem 'watir'"
    end
    case framework
    when 'rspec'    then gems << "gem 'rspec'"
    when 'cucumber' then gems << "gem 'cucumber'"
    end
    File.write("#{dir}/Gemfile", gems.join("\n") + "\n")
    File.write("#{dir}/config/config.yml", "browser: chrome\nurl: http://localhost:3000\n")
    File.write("#{dir}/page_objects/abstract/page.rb", "class Page; end\n")
    File.write("#{dir}/page_objects/abstract/component.rb", "class Component; end\n")

    dir
  end

  # ──────────────────────────────────────────────
  # Shared examples: Page object content
  # ──────────────────────────────────────────────

  shared_examples 'valid scaffolded page' do
    it 'has frozen_string_literal' do
      expect(page_content).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(page_content).to have_valid_ruby_syntax
    end

    it 'inherits from Page' do
      expect(page_content).to include('class CheckoutPage < Page')
    end

    it 'requires abstract page' do
      expect(page_content).to include("require_relative '../abstract/page'")
    end

    it 'includes url method (config has url)' do
      expect(page_content).to include("def url(_page)")
      expect(page_content).to include("'checkout'")
    end
  end

  shared_examples 'selenium scaffolded page' do
    it 'has driver.find_element example' do
      expect(page_content).to include('driver.find_element')
    end

    it 'has private section' do
      expect(page_content).to include('private')
    end

    it 'does not have capybara fill_in' do
      expect(page_content).not_to include('fill_in')
    end

    it 'does not have watir browser.text_field' do
      expect(page_content).not_to include('browser.text_field')
    end
  end

  shared_examples 'watir scaffolded page' do
    it 'has browser.text_field example' do
      expect(page_content).to include('browser.text_field')
    end

    it 'has private section' do
      expect(page_content).to include('private')
    end

    it 'does not have selenium find_element' do
      expect(page_content).not_to include('driver.find_element')
    end

    it 'does not have capybara fill_in' do
      expect(page_content).not_to include('fill_in')
    end
  end

  # ──────────────────────────────────────────────
  # Shared examples: Spec content (RSpec)
  # ──────────────────────────────────────────────

  shared_examples 'valid scaffolded spec' do
    it 'has frozen_string_literal' do
      expect(spec_content).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(spec_content).to have_valid_ruby_syntax
    end

    it 'describes the page class' do
      expect(spec_content).to include("describe 'CheckoutPage'")
    end

    it 'requires the page object' do
      expect(spec_content).to include("require_relative '../page_objects/pages/checkout'")
    end

    it 'has pending test' do
      expect(spec_content).to include("pending 'implement test'")
    end

    it 'has before block with navigation' do
      expect(spec_content).to include('before do')
    end
  end

  shared_examples 'selenium scaffolded spec' do
    it 'instantiates page with driver' do
      expect(spec_content).to include('CheckoutPage.new(driver)')
    end

    it 'navigates with driver' do
      expect(spec_content).to include('driver.navigate.to')
    end

    it 'does not use capybara visit' do
      expect(spec_content).not_to match(/^\s+visit '/)
    end
  end

  shared_examples 'watir scaffolded spec' do
    it 'instantiates page with browser' do
      expect(spec_content).to include('CheckoutPage.new(browser)')
    end

    it 'navigates with browser.goto' do
      expect(spec_content).to include('browser.goto')
    end
  end

  # ──────────────────────────────────────────────
  # Shared examples: Feature content (Cucumber)
  # ──────────────────────────────────────────────

  shared_examples 'valid scaffolded feature' do
    it 'has Feature keyword' do
      expect(feature_content).to include('Feature: Checkout')
    end

    it 'has Scenario keyword' do
      expect(feature_content).to include('Scenario: Scenario name')
    end

    it 'has Given/When/Then steps' do
      expect(feature_content).to include('Given I am on the checkout page')
      expect(feature_content).to include('When I perform an action')
      expect(feature_content).to include('Then I see the expected result')
    end
  end

  # ──────────────────────────────────────────────
  # Shared examples: Steps content (Cucumber)
  # ──────────────────────────────────────────────

  shared_examples 'valid scaffolded steps' do
    it 'has frozen_string_literal' do
      expect(steps_content).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(steps_content).to have_valid_ruby_syntax
    end

    it 'requires the page object' do
      expect(steps_content).to include("require_relative '../../page_objects/pages/checkout'")
    end

    it 'has Given/When/Then blocks' do
      expect(steps_content).to include("Given('I am on the checkout page')")
      expect(steps_content).to include("When('I perform an action')")
      expect(steps_content).to include("Then('I see the expected result')")
    end

    it 'has pending steps' do
      expect(steps_content).to include("pending 'implement step'")
    end
  end

  shared_examples 'selenium scaffolded steps' do
    it 'instantiates page with driver' do
      expect(steps_content).to include('CheckoutPage.new(driver)')
    end

    it 'does not use capybara visit' do
      expect(steps_content).not_to match(/^\s+visit '/)
    end
  end

  shared_examples 'watir scaffolded steps' do
    it 'instantiates page with browser' do
      expect(steps_content).to include('CheckoutPage.new(browser)')
    end
  end

  # ──────────────────────────────────────────────
  # Shared examples: Helper content
  # ──────────────────────────────────────────────

  shared_examples 'valid scaffolded helper' do
    it 'has frozen_string_literal' do
      expect(helper_content).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(helper_content).to have_valid_ruby_syntax
    end

    it 'defines helper module' do
      expect(helper_content).to include('module CheckoutHelper')
    end

    it 'has helper placeholder comment' do
      expect(helper_content).to include('# Add your helper code here')
    end
  end

  # ──────────────────────────────────────────────
  # Shared examples: Component content
  # ──────────────────────────────────────────────

  shared_examples 'valid scaffolded component' do
    it 'has frozen_string_literal' do
      expect(component_content).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(component_content).to have_valid_ruby_syntax
    end

    it 'inherits from Component' do
      expect(component_content).to include('class Sidebar < Component')
    end

    it 'requires abstract component' do
      expect(component_content).to include("require_relative '../abstract/component'")
    end
  end

  shared_examples 'selenium scaffolded component' do
    it 'has driver.find_element example' do
      expect(component_content).to include('driver.find_element')
    end

    it 'has private section' do
      expect(component_content).to include('private')
    end

    it 'has content method' do
      expect(component_content).to include('def content')
    end
  end

  shared_examples 'watir scaffolded component' do
    it 'has browser.element example' do
      expect(component_content).to include('browser.element')
    end

    it 'has private section' do
      expect(component_content).to include('private')
    end

    it 'has content method' do
      expect(component_content).to include('def content')
    end
  end

  # ══════════════════════════════════════════════
  # Test matrix: automation × framework
  # ══════════════════════════════════════════════

  WEB_AUTOMATIONS.each do |automation|
    TEST_FRAMEWORKS.each do |framework|
      style = scaffold_style(framework)

      context "with #{framework} and #{automation}" do # rubocop:disable RSpec/ContextWording
        let(:scaffold) { ScaffoldingCommands }

        # Use absolute path so Dir.chdir is safe regardless of current CWD
        project_dir = build_mock_project(automation, framework)

        before do
          Dir.chdir(project_dir)
        end

        after do
          Dir.chdir(File.dirname(project_dir))
        end

        after(:all) do # rubocop:disable RSpec/BeforeAfterAll
          FileUtils.rm_rf(project_dir)
        end

        # ── Default scaffold ───────────────────

        describe 'default scaffold' do
          before do
            scaffold.new.invoke(:scaffold, nil, %w[checkout])
          end

          after do
            FileUtils.rm_f('page_objects/pages/checkout.rb')
            FileUtils.rm_f('spec/checkout_page_spec.rb')
            if framework == 'cucumber'
              FileUtils.rm_f('features/checkout.feature')
              FileUtils.rm_f('features/step_definitions/checkout_steps.rb')
            else
              FileUtils.rm_rf('features')
              FileUtils.rm_rf('spec') unless framework == 'rspec'
            end
          end

          it 'creates page object' do
            expect(Pathname.new('page_objects/pages/checkout.rb')).to be_file
          end

          if style == :spec
            it 'creates spec file' do
              expect(Pathname.new('spec/checkout_page_spec.rb')).to be_file
            end

            it 'does not create feature file' do
              expect(Pathname.new('features/checkout.feature')).not_to be_file
            end
          else # :feature
            it 'creates feature file' do
              expect(Pathname.new('features/checkout.feature')).to be_file
            end

            it 'creates steps file' do
              expect(Pathname.new('features/step_definitions/checkout_steps.rb')).to be_file
            end
          end

          # Page content validation
          let(:page_content) { File.read('page_objects/pages/checkout.rb') }

          include_examples 'valid scaffolded page'
          include_examples "#{automation} scaffolded page"

          # Test content validation (depends on scaffold style)
          if style == :spec
            let(:spec_content) { File.read('spec/checkout_page_spec.rb') }
            include_examples 'valid scaffolded spec'
            include_examples "#{automation} scaffolded spec"
          else # :feature
            let(:feature_content) { File.read('features/checkout.feature') }
            include_examples 'valid scaffolded feature'

            let(:steps_content) { File.read('features/step_definitions/checkout_steps.rb') }
            include_examples 'valid scaffolded steps'
            include_examples "#{automation} scaffolded steps"
          end
        end

        # ── Component scaffold ─────────────────

        describe 'component scaffold' do
          before do
            scaffold.new.invoke(:component, nil, %w[sidebar])
          end

          after do
            FileUtils.rm_f('page_objects/components/sidebar.rb')
          end

          let(:component_content) { File.read('page_objects/components/sidebar.rb') }

          include_examples 'valid scaffolded component'
          include_examples "#{automation} scaffolded component"
        end

        # ── Helper scaffold ────────────────────

        describe 'helper scaffold' do
          before do
            scaffold.new.invoke(:helper, nil, %w[checkout])
          end

          after do
            FileUtils.rm_f('helpers/checkout_helper.rb')
          end

          let(:helper_content) { File.read('helpers/checkout_helper.rb') }

          include_examples 'valid scaffolded helper'
        end

        # ── Batch scaffold ─────────────────────

        describe 'batch scaffold' do
          after do
            %w[search filter].each do |name|
              FileUtils.rm_f("page_objects/pages/#{name}.rb")
              FileUtils.rm_f("spec/#{name}_page_spec.rb")
              FileUtils.rm_f("features/#{name}.feature")
              FileUtils.rm_f("features/step_definitions/#{name}_steps.rb")
            end
            FileUtils.rm_rf('features') unless framework == 'cucumber'
            FileUtils.rm_rf('spec') unless framework == 'rspec'
          end

          it 'generates multiple scaffolds at once' do
            scaffold.new.invoke(:scaffold, nil, %w[search filter])
            expect(Pathname.new('page_objects/pages/search.rb')).to be_file
            expect(Pathname.new('page_objects/pages/filter.rb')).to be_file

            if style == :spec
              expect(Pathname.new('spec/search_page_spec.rb')).to be_file
              expect(Pathname.new('spec/filter_page_spec.rb')).to be_file
            else
              expect(Pathname.new('features/search.feature')).to be_file
              expect(Pathname.new('features/filter.feature')).to be_file
            end
          end
        end

        # ── Name normalization ─────────────────

        describe 'name normalization' do
          after do
            %w[cart shopping_cart checkout].each do |name|
              FileUtils.rm_f("page_objects/pages/#{name}.rb")
            end
          end

          it 'strips _page suffix' do
            scaffold.new.invoke(:page, nil, %w[cart_page])
            expect(Pathname.new('page_objects/pages/cart.rb')).to be_file
          end

          it 'converts CamelCase to snake_case' do
            scaffold.new.invoke(:page, nil, %w[ShoppingCart])
            expect(Pathname.new('page_objects/pages/shopping_cart.rb')).to be_file
          end

          it 'handles CamelCase with Page suffix' do
            scaffold.new.invoke(:page, nil, %w[CheckoutPage])
            expect(Pathname.new('page_objects/pages/checkout.rb')).to be_file
          end
        end

      end
    end
  end
end
