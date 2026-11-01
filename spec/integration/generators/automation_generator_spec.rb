# frozen_string_literal: true

require_relative '../../../lib/generators/automation/automation_generator'
require_relative '../spec_helper'

describe AutomationGenerator do
  shared_examples 'creates web automation framework' do |name|
    it 'creates a login page file' do
      expect(File).to exist("#{name}/page_objects/pages/login.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/page.rb")
    end

    it 'creates an abstract component file' do
      expect(File).to exist("#{name}/page_objects/abstract/component.rb")
    end

    it 'creates a component file' do
      expect(File).to exist("#{name}/page_objects/components/header.rb")
    end
  end

  shared_examples 'creates mobile automation framework' do |name|
    it 'creates a home page file' do
      expect(File).to exist("#{name}/page_objects/pages/home.rb")
    end

    it 'creates an abstract page file' do
      expect(File).to exist("#{name}/page_objects/abstract/page.rb")
    end

    it 'creates a pdp page file' do
      expect(File).to exist("#{name}/page_objects/pages/pdp.rb")
    end
  end

  context 'with rspec and selenium' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
  end

  context 'with rspec and watir' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
  end

  context 'with cucumber and selenium' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
  end

  context 'with cucumber and watir' do
    include_examples 'creates web automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
  end

  context 'with rspec and appium android' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::ANDROID}"
  end

  context 'with rspec and appium ios' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::RSPEC}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium android' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}"
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}"
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates mobile automation framework', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}"
  end

  describe 'without example tests' do
    %w[rspec cucumber].product(%w[selenium ios cross_platform]).each do |framework, automation|
      context "with #{framework} and #{automation}" do
        let(:name) { ensure_project(framework:, automation:, examples: false) }

        it 'creates no example pages' do
          expect(Dir.glob("#{name}/page_objects/pages/*.rb")).to be_empty
        end

        it 'keeps the pages folder with a .keep' do
          expect(File).to exist("#{name}/page_objects/pages/.keep")
        end

        it 'creates the abstract page' do
          expect(File).to exist("#{name}/page_objects/abstract/page.rb")
        end

        it 'gives the abstract page no header component' do
          expect(File.read("#{name}/page_objects/abstract/page.rb")).not_to include('Header')
        end

        it 'creates no models' do
          expect(File).not_to exist("#{name}/models")
        end
      end
    end

    context 'with a web project' do
      let(:name) { ensure_project(framework: 'rspec', automation: 'selenium', examples: false) }

      it 'creates the abstract component' do
        expect(File).to exist("#{name}/page_objects/abstract/component.rb")
      end

      it 'keeps the components folder with a .keep and no example component' do
        expect(Dir.children("#{name}/page_objects/components")).to eq(['.keep'])
      end
    end

    context 'with watir' do
      it 'still creates the examples, because the Watir templates are frozen' do
        InvokeGenerators.generate_framework(framework: 'rspec', automation: 'watir', name: 'skeleton_watir',
                                            examples: false)
        expect(File).to exist('skeleton_watir/page_objects/pages/login.rb')
      ensure
        FileUtils.rm_rf('skeleton_watir')
      end
    end
  end
end
