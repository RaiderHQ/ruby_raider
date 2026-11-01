# frozen_string_literal: true

require 'rspec'
require_relative '../../lib/generators/menu_generator'

RSpec.describe MenuGenerator do
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:menu_generator) { described_class.new('test_project') }

  before do
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
  end

  describe '#generate_choice_menu' do
    it 'presents automation framework selection' do
      menu = double('menu') # rubocop:disable RSpec/VerifiedDoubles
      allow(menu).to receive(:choice)
      allow(prompt).to receive(:select).with('Please select your automation framework').and_yield(menu)

      menu_generator.generate_choice_menu

      expect(menu).to have_received(:choice).with(:Selenium, anything)
      expect(menu).to have_received(:choice).with(:Appium, anything)
      expect(menu).to have_received(:choice).with(:Quit, anything)
      expect(menu).not_to have_received(:choice).with(:Watir, anything)
      expect(menu).to have_received(:choice).exactly(3).times
    end
  end

  describe '#choose_test_framework' do
    context 'with a web automation' do
      it 'presents test framework selection' do
        menu = double('menu') # rubocop:disable RSpec/VerifiedDoubles
        allow(menu).to receive(:choice)
        allow(prompt).to receive(:select).with('Please select your test framework').and_yield(menu)

        menu_generator.choose_test_framework('selenium')

        expect(menu).to have_received(:choice).with(:Cucumber, anything)
        expect(menu).to have_received(:choice).with(:Rspec, anything)
        expect(menu).to have_received(:choice).with(:Quit, anything)
      end
    end

    context 'with appium' do
      it 'presents mobile platform selection' do
        menu = double('menu') # rubocop:disable RSpec/VerifiedDoubles
        allow(menu).to receive(:choice)
        allow(prompt).to receive(:select).with('Please select your mobile platform').and_yield(menu)

        menu_generator.choose_test_framework('appium')

        expect(menu).to have_received(:choice).with(:iOS, anything)
        expect(menu).to have_received(:choice).with(:Android, anything)
        expect(menu).to have_received(:choice).with(:Cross_Platform, anything)
        expect(menu).to have_received(:choice).with(:Quit, anything)
      end
    end
  end

  describe '#set_up_framework' do
    let(:options) do
      { automation: 'selenium', framework: 'rspec', accessibility: true }
    end

    before do
      allow(prompt).to receive(:yes?).and_return(false)
    end

    it 'calls generate_framework with correct structure' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)

      menu_generator.set_up_framework(options)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(
          automation: 'selenium',
          framework: 'rspec',
          accessibility: true,
          name: 'test_project'
        )
      )
    end

    it 'runs bundle install in the generated project' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)

      menu_generator.set_up_framework(options)

      expect(menu_generator).to have_received(:system).with('cd test_project && gem install bundler && bundle install')
    end
  end

  describe 'full flow: selenium + rspec' do
    it 'calls set_up_framework with correct options' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Rspec', 'selenium')

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', name: 'test_project')
      )
    end
  end

  describe 'full flow: watir + cucumber' do
    it 'calls set_up_framework with correct options' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Cucumber', 'watir')

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(
          automation: 'watir',
          framework: 'cucumber',
          accessibility: false,
          name: 'test_project'
        )
      )
    end
  end

  describe 'full flow: selenium + rspec + accessibility' do
    it 'passes accessibility flag through' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Rspec', 'selenium', accessibility: true)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', accessibility: true)
      )
    end
  end

  describe 'project name propagation' do
    it 'uses the project name from initialization' do
      generator = described_class.new('my_custom_project')
      allow(generator).to receive(:generate_framework)
      allow(generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      generator.send(:create_framework, 'Rspec', 'selenium')

      expect(generator).to have_received(:generate_framework).with(
        hash_including(name: 'my_custom_project')
      )
    end
  end

  describe 'CI provider question' do
    let(:menu) { double('menu') } # rubocop:disable RSpec/VerifiedDoubles

    before do
      allow(menu).to receive(:choice)
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)
    end

    it 'is asked after accessibility for web automations' do
      allow(prompt).to receive(:select).with('Which CI provider?').and_yield(menu)

      menu_generator.send(:select_ci, 'Rspec', 'selenium', accessibility: false)

      expect(menu).to have_received(:choice).with('GitHub Actions', anything)
      expect(menu).to have_received(:choice).with('Azure Pipelines', anything)
      expect(menu).to have_received(:choice).with(:Quit, anything)
    end

    it 'follows the accessibility answer' do
      allow(prompt).to receive(:select).with('Add accessibility testing (axe)?').and_yield(menu)
      allow(menu).to receive(:choice).with(:No, anything) { |_, action| action.call }
      allow(menu_generator).to receive(:select_ci)

      menu_generator.send(:select_accessibility, 'Rspec', 'selenium')

      expect(menu_generator).to have_received(:select_ci).with('Rspec', 'selenium', accessibility: false, examples: true)
    end

    it 'is skipped for mobile' do
      allow(prompt).to receive(:select)

      menu_generator.send(:select_accessibility, 'Rspec', 'ios')

      expect(prompt).not_to have_received(:select)
      expect(menu_generator).to have_received(:generate_framework).with(hash_including(automation: 'ios'))
    end

    it 'passes ci azure through to generate_framework' do
      menu_generator.send(:create_framework, 'Rspec', 'selenium', ci_provider: 'azure')

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', ci: 'azure')
      )
    end
  end

  describe 'example tests question' do
    let(:menu) { double('menu') } # rubocop:disable RSpec/VerifiedDoubles

    before do
      allow(menu).to receive(:choice)
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)
    end

    it 'is asked after the test framework question' do
      allow(prompt).to receive(:select).with('Please select your test framework').and_yield(menu)
      allow(menu).to receive(:choice).with(:Rspec, anything) { |_, action| action.call }
      allow(menu_generator).to receive(:select_examples)

      menu_generator.choose_test_framework('selenium')

      expect(menu_generator).to have_received(:select_examples).with('Rspec', 'selenium')
    end

    it 'offers Yes first, so yes is the default' do
      allow(prompt).to receive(:select).with('Do you want example tests?').and_yield(menu)
      allow(menu).to receive(:choice).with(:Yes, anything) { |_, action| action.call }
      allow(menu_generator).to receive(:select_accessibility)

      menu_generator.send(:select_examples, 'Rspec', 'selenium')

      expect(menu).to have_received(:choice).with(:Yes, anything).ordered
      expect(menu).to have_received(:choice).with(:No, anything).ordered
      expect(menu).to have_received(:choice).with(:Quit, anything).ordered
      expect(menu_generator).to have_received(:select_accessibility).with('Rspec', 'selenium', examples: true)
    end

    it 'carries No through to generate_framework as examples: false' do
      allow(prompt).to receive(:select).with('Do you want example tests?').and_yield(menu)
      allow(menu).to receive(:choice).with(:No, anything) { |_, action| action.call }
      allow(prompt).to receive(:select).with('Add accessibility testing (axe)?').and_yield(menu)
      allow(menu).to receive(:choice).with(:No, anything) { |_, action| action.call }
      allow(prompt).to receive(:select).with('Which CI provider?').and_yield(menu)
      allow(menu).to receive(:choice).with('GitHub Actions', anything) { |_, action| action.call }

      menu_generator.send(:select_examples, 'Rspec', 'selenium')

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', examples: false)
      )
    end

    it 'carries No through for mobile, which has no accessibility question' do
      allow(prompt).to receive(:select).with('Do you want example tests?').and_yield(menu)
      allow(menu).to receive(:choice).with(:No, anything) { |_, action| action.call }

      menu_generator.send(:select_examples, 'Cucumber', 'ios')

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'ios', framework: 'cucumber', examples: false)
      )
    end
  end
end
