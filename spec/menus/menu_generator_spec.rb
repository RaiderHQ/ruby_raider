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
      expect(menu).to have_received(:choice).with(:Capybara, anything)
      expect(menu).to have_received(:choice).with(:Appium, anything)
      expect(menu).to have_received(:choice).with(:Watir, anything)
      expect(menu).to have_received(:choice).with(:Quit, anything)
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
        expect(menu).to have_received(:choice).with(:Minitest, anything)
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
      { automation: 'selenium', framework: 'rspec', ci_platform: 'github', accessibility: true }
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
          ci_platform: 'github',
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

  describe 'full flow: selenium + rspec + no CI' do
    it 'calls set_up_framework with correct options' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Rspec', 'selenium', nil, nil, false, false, false)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', name: 'test_project')
      )
    end
  end

  describe 'full flow: capybara + minitest + github' do
    it 'calls set_up_framework with correct options' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Minitest', 'capybara', 'github', nil, false, false, false)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(
          automation: 'capybara',
          framework: 'minitest',
          ci_platform: 'github',
          accessibility: false,
          name: 'test_project'
        )
      )
    end
  end

  describe 'full flow: watir + cucumber + gitlab' do
    it 'calls set_up_framework with correct options' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Cucumber', 'watir', 'gitlab', nil, false, false, false)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(
          automation: 'watir',
          framework: 'cucumber',
          ci_platform: 'gitlab',
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

      menu_generator.send(:create_framework, 'Rspec', 'selenium', nil, nil, true, false, false)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', accessibility: true)
      )
    end
  end

  describe 'full flow: selenium + rspec + visual' do
    it 'passes visual flag through' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Rspec', 'selenium', nil, nil, false, true, false)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', visual: true)
      )
    end
  end

  describe 'full flow: selenium + rspec + performance' do
    it 'passes performance flag through' do
      allow(menu_generator).to receive(:generate_framework)
      allow(menu_generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      menu_generator.send(:create_framework, 'Rspec', 'selenium', nil, nil, false, false, true)

      expect(menu_generator).to have_received(:generate_framework).with(
        hash_including(automation: 'selenium', framework: 'rspec', performance: true)
      )
    end
  end

  describe 'reporter selection menu' do
    it 'includes JSON and All reporter choices' do # rubocop:disable RSpec/MultipleExpectations
      menu = double('menu') # rubocop:disable RSpec/VerifiedDoubles
      allow(menu).to receive(:choice)
      allow(prompt).to receive(:select).with('Select your test reporter').and_yield(menu)

      menu_generator.send(:select_reporter, 'Rspec', 'selenium')

      expect(menu).to have_received(:choice).with(:JSON, anything)
      expect(menu).to have_received(:choice).with(:All, anything)
      expect(menu).to have_received(:choice).with(:Allure, anything)
      expect(menu).to have_received(:choice).with(:JUnit, anything)
      expect(menu).to have_received(:choice).with(:Both, anything)
      expect(menu).to have_received(:choice).with(:None, anything)
    end
  end

  describe 'project name propagation' do
    it 'uses the project name from initialization' do
      generator = described_class.new('my_custom_project')
      allow(generator).to receive(:generate_framework)
      allow(generator).to receive(:system)
      allow(prompt).to receive(:say)
      allow(prompt).to receive(:yes?).and_return(false)

      generator.send(:create_framework, 'Rspec', 'selenium', nil, nil, false, false, false)

      expect(generator).to have_received(:generate_framework).with(
        hash_including(name: 'my_custom_project')
      )
    end
  end
end
