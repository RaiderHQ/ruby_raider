# frozen_string_literal: true

require_relative 'content_helper'

describe 'Test file content' do
  # --- RSpec specs ---

  shared_examples 'valid rspec spec' do |project_name|
    subject(:spec) { read_generated(project_name, 'spec/login_page_spec.rb') }

    it 'has frozen_string_literal' do
      expect(spec).to have_frozen_string_literal
    end

    it 'has valid Ruby syntax' do
      expect(spec).to have_valid_ruby_syntax
    end

    it 'uses describe block' do
      expect(spec).to match(/describe 'Login'/)
    end

    it 'requires spec_helper' do
      expect(spec).to include("require_relative '../helpers/spec_helper'")
    end

    it 'requires model_factory' do
      expect(spec).to include("require_relative '../models/model_factory'")
    end

    it 'requires login page' do
      expect(spec).to include("require_relative '../page_objects/pages/login'")
    end

    it 'has before block' do
      expect(spec).to match(/before do/)
    end

    it 'has context blocks' do
      expect(spec).to include("context 'with right credentials'")
      expect(spec).to include("context 'with wrong credentials'")
    end
  end

  shared_examples 'selenium rspec spec' do |project_name|
    subject(:spec) { read_generated(project_name, 'spec/login_page_spec.rb') }

    it 'instantiates Login with driver' do
      expect(spec).to include('Login.new(driver)')
    end

    it 'uses visit method' do
      expect(spec).to include('.visit')
      expect(spec).not_to include('.visit_page')
    end
  end

  shared_examples 'watir rspec spec' do |project_name|
    subject(:spec) { read_generated(project_name, 'spec/login_page_spec.rb') }

    it 'instantiates Login with browser' do
      expect(spec).to include('Login.new(browser)')
    end

    it 'uses visit method' do
      expect(spec).to include('.visit')
      expect(spec).not_to include('.visit_page')
    end
  end

  # --- Cucumber features and steps ---

  shared_examples 'valid cucumber feature' do |project_name|
    subject(:feature) { read_generated(project_name, 'features/login.feature') }

    it 'has Feature keyword' do
      expect(feature).to match(/Feature:/)
    end

    it 'has Scenario keyword' do
      expect(feature).to match(/Scenario:/)
    end

    it 'has Given/When/Then steps' do
      expect(feature).to match(/Given/)
      expect(feature).to match(/When/)
      expect(feature).to match(/Then/)
    end
  end

  shared_examples 'valid cucumber env' do |project_name|
    subject(:env) { read_generated(project_name, 'features/support/env.rb') }

    it 'has valid Ruby syntax' do
      expect(env).to have_valid_ruby_syntax
    end
  end

  shared_examples 'valid cucumber world' do |project_name|
    subject(:world) { read_generated(project_name, 'features/support/world.rb') }

    it 'has valid Ruby syntax' do
      expect(world).to have_valid_ruby_syntax
    end
  end

  shared_examples 'valid cucumber config' do |project_name|
    subject(:config) { read_generated(project_name, 'cucumber.yml') }

    it 'has default profile' do
      expect(config).to include('default:')
    end
  end

  # --- RSpec contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid rspec spec', name
    include_examples 'selenium rspec spec', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid rspec spec', name
    include_examples 'watir rspec spec', name
  end

  # --- Cucumber contexts ---

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid cucumber feature', name
    include_examples 'valid cucumber env', name
    include_examples 'valid cucumber world', name
    include_examples 'valid cucumber config', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'valid cucumber feature', name
    include_examples 'valid cucumber env', name
    include_examples 'valid cucumber world', name
    include_examples 'valid cucumber config', name
  end

end
