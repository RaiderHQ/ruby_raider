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

    it 'uses the pretty and rerun formatters, with the reporter activated from env.rb' do
      expect(config.strip).to eq('default: --format pretty --format rerun --out rerun.txt --publish-quiet --retry 0')
    end
  end

  shared_examples 'logged in example' do |project_name|
    it 'adds a :logged_in example that reuses the saved login and keeps the login example' do
      spec = read_generated(project_name, 'spec/login_page_spec.rb')
      expect(spec).to include("describe 'Account', :logged_in", 'opens the account page with the saved login',
                              "describe 'Login' do", 'can successfully log in')
    end
  end

  shared_examples 'logged in scenario' do |project_name|
    it 'adds a @logged_in scenario and keeps the login scenario' do
      feature = read_generated(project_name, 'features/login.feature')
      expect(feature).to include("@logged_in\nScenario: A logged-in user opens the account page",
                                 "Given I'm a registered user\n", 'Scenario: A user can login')
    end

    it 'defines the step that picks the user without logging in' do
      steps = read_generated(project_name, 'features/step_definitions/login_steps.rb')
      expect(steps).to include(%q(Given("I'm a {user}") do |user|))
    end
  end

  # --- RSpec contexts ---

  context 'with rspec and selenium' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid rspec spec', name
    include_examples 'selenium rspec spec', name
    include_examples 'logged in example', name
  end

  context 'with rspec and watir' do
    name = "#{FrameworkIndex::RSPEC}_#{AutomationIndex::WATIR}"
    include_examples 'valid rspec spec', name
    include_examples 'watir rspec spec', name
    include_examples 'logged in example', name
  end

  # --- Cucumber contexts ---

  context 'with cucumber and selenium' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::SELENIUM}"
    include_examples 'valid cucumber feature', name
    include_examples 'valid cucumber env', name
    include_examples 'valid cucumber world', name
    include_examples 'valid cucumber config', name
    include_examples 'logged in scenario', name
  end

  context 'with cucumber and watir' do
    name = "#{FrameworkIndex::CUCUMBER}_#{AutomationIndex::WATIR}"
    include_examples 'valid cucumber feature', name
    include_examples 'valid cucumber env', name
    include_examples 'valid cucumber world', name
    include_examples 'valid cucumber config', name
    include_examples 'logged in scenario', name
  end
end

describe 'Cucumber world WaitHelper wiring' do
  %w[selenium ios android cross_platform].each do |automation|
    it "makes WaitHelper available to steps in #{automation}" do
      world = read_generated("cucumber_#{automation}", 'features/support/world.rb')
      expect(world).to include("require_relative '../../helpers/wait_helper'", 'World(WaitHelper)')
    end
  end

  it 'leaves the watir world without WaitHelper' do
    expect(read_generated('cucumber_watir', 'features/support/world.rb')).not_to include('WaitHelper')
  end
end

describe 'Example tests on the wait helper' do
  it 'wraps every assertion of the selenium rspec spec in eventually' do
    spec = read_generated('rspec_selenium', 'spec/login_page_spec.rb')
    expect(spec.scan('eventually { expect(').size).to eq(3)
    expect(spec.scan(/^ +expect\(/)).to be_empty
  end

  it "wraps the selenium cucumber Then step's assertion in eventually" do
    steps = read_generated('cucumber_selenium', 'features/step_definitions/login_steps.rb')
    expect(steps).to include('eventually { expect(account_page.header.customer_name).to eq ')
  end

  %w[ios android cross_platform].each do |automation|
    it "wraps the #{automation} rspec assertion in eventually" do
      spec = read_generated("rspec_#{automation}", 'spec/pdp_page_spec.rb')
      expect(spec).to include("eventually { expect(pdp_page.add_to_cart_text).to eq 'Add to Cart' }")
    end

    it "wraps the #{automation} cucumber Then step's assertion in eventually" do
      steps = read_generated("cucumber_#{automation}", 'features/step_definitions/home_steps.rb')
      expect(steps).to include("eventually { expect(pdp_page.add_to_cart_text).to eq 'Add to Cart' }")
    end
  end
end

# The Watir output must stay as master generated it (1274a66); the snapshots in
# spec/fixtures/watir_master were generated from that commit's lib.
describe 'Watir example output' do
  snapshots = File.expand_path('../../fixtures/watir_master', __dir__)

  { 'rspec_watir' => %w[page_objects/pages/login.rb page_objects/abstract/page.rb spec/login_page_spec.rb Readme.md],
    'cucumber_watir' => %w[page_objects/pages/login.rb page_objects/abstract/page.rb
                           features/step_definitions/login_steps.rb Readme.md] }.each do |project, files|
    files.each do |file|
      it "keeps #{project}/#{file} as master generates it" do
        expected = File.read(File.join(snapshots, project, "#{file}.snapshot"))
        expect(read_generated(project, file)).to eq(expected)
      end
    end
  end
end
