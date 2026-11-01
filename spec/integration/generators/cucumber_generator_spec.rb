# frozen_string_literal: true

require_relative '../../../lib/generators/cucumber/cucumber_generator'
require_relative '../spec_helper'

describe CucumberGenerator do
  shared_examples 'creates cucumber files' do |project_name, file_name|
    it 'creates a feature file' do
      expect(File).to exist("#{project_name}/features/#{file_name}.feature")
    end

    it 'creates a step definitions file' do
      expect(File).to exist("#{project_name}/features/step_definitions/#{file_name}_steps.rb")
    end

    it 'creates an env file' do
      expect(File).to exist("#{project_name}/features/support/env.rb")
    end

    it 'creates an cucumber.yml file' do
      expect(File).to exist("#{project_name}/cucumber.yml")
    end

    it 'does not create a spec file' do
      expect(File).not_to exist("#{project_name}/spec/home_spec.rb")
    end
  end

  shared_examples 'creates factories for web projects' do |project_name|
    it 'creates an data file' do
      expect(File).to exist("#{project_name}/models/data/users.yml")
    end

    it 'creates a model factory' do
      expect(File).to exist("#{project_name}/models/model_factory.rb")
    end

    it 'creates a user factory' do
      expect(File).to exist("#{project_name}/models/user_factory.rb")
    end
  end

  context 'with cucumber and appium android' do
    include_examples 'creates cucumber files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::ANDROID}", 'home'
  end

  context 'with cucumber and appium ios' do
    include_examples 'creates cucumber files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::IOS}", 'home'
  end

  context 'with cucumber and appium cross platform' do
    include_examples 'creates cucumber files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::CROSS_PLATFORM}", 'home'
  end

  context 'with cucumber and selenium' do
    include_examples 'creates cucumber files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}", 'login'
    include_examples 'creates factories for web projects', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}", 'login'
  end

  context 'with cucumber and watir' do
    include_examples 'creates cucumber files', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}", 'login'
    include_examples 'creates factories for web projects', "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}", 'login'
  end

  describe 'without example tests' do
    %w[selenium ios cross_platform].each do |automation|
      context "with cucumber and #{automation}" do
        let(:name) { ensure_project(framework: 'cucumber', automation:, examples: false) }

        it 'creates no feature files' do
          expect(Dir.glob("#{name}/features/**/*.feature")).to be_empty
        end

        it 'keeps an empty step_definitions folder' do
          expect(Dir.children("#{name}/features/step_definitions")).to eq(['.keep'])
        end

        it 'creates the support files' do
          expect(Dir.children("#{name}/features/support")).to contain_exactly('env.rb', 'world.rb')
        end

        it 'creates the cucumber.yml file' do
          expect(File).to exist("#{name}/cucumber.yml")
        end

        it 'creates no user factory' do
          expect(File).not_to exist("#{name}/models/user_factory.rb")
        end
      end
    end

    it 'creates no accessibility example' do
      InvokeGenerators.generate_framework(framework: 'cucumber', automation: 'selenium', name: 'skeleton_axe_cucumber',
                                          examples: false, accessibility: true)
      expect(Dir.glob('skeleton_axe_cucumber/features/**/accessibility*')).to be_empty
    ensure
      FileUtils.rm_rf('skeleton_axe_cucumber')
    end
  end
end
