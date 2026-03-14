# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative '../../../lib/generators/invoke_generators'
require_relative '../../../lib/commands/utility_commands'
require_relative '../../../lib/utilities/utilities'

# Standalone test — does NOT require spec_helper to avoid generating all 54 projects.
# Generates only the specific projects needed for browser update testing.

describe 'Browser update after framework creation' do
  include InvokeGenerators

  orig_dir = Dir.pwd

  def generate_project(framework:, automation:)
    name = "browser_update_#{framework}_#{automation}"
    generate_framework(automation: automation, framework: framework, name: name)
    name
  end

  after do
    Dir.chdir orig_dir
  end

  shared_examples 'updates browser config after creation' do |framework, automation|
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      @project_name = generate_project(framework: framework, automation: automation)
    end

    after(:all) do # rubocop:disable RSpec/BeforeAfterAll
      Dir.chdir orig_dir
      FileUtils.rm_rf(@project_name) if @project_name
    end

    before do
      Dir.chdir @project_name
    end

    it 'starts with chrome as default browser' do
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql 'chrome'
    end

    it 'strips colon prefix when setting browser' do
      UtilityCommands.new.invoke(:browser, nil, %w[:firefox])
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql 'firefox'
    end

    it 'stores browser without colon so browser_arguments keys match' do
      UtilityCommands.new.invoke(:browser, nil, %w[:firefox])
      config = YAML.load_file('config/config.yml')
      expect(config['browser_arguments']).to have_key('firefox')
    end

    it 'sets browser arguments for the current browser' do
      UtilityCommands.new.invoke(:browser, nil, %w[:chrome --opts headless no-sandbox])
      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql 'chrome'
      expect(config['browser_arguments']['chrome']).to eql %w[headless no-sandbox]
    end

    it 'enables headless mode via config key' do
      UtilityCommands.new.invoke(:headless, nil, %w[on])
      config = YAML.load_file('config/config.yml')
      expect(config['headless']).to be true
    end

    it 'disables headless mode via config key' do
      UtilityCommands.new.invoke(:headless, nil, %w[on])
      UtilityCommands.new.invoke(:headless, nil, %w[off])
      config = YAML.load_file('config/config.yml')
      expect(config['headless']).to be false
    end

    it 'updates viewport dimensions' do
      UtilityCommands.new.invoke(:viewport, nil, %w[375x812])
      config = YAML.load_file('config/config.yml')
      expect(config['viewport']).to eq({ 'width' => 375, 'height' => 812 })
    end

    it 'updates timeout' do
      UtilityCommands.new.invoke(:timeout, nil, %w[30])
      config = YAML.load_file('config/config.yml')
      expect(config['timeout']).to eq 30
    end

    it 'applies multiple sequential updates without losing earlier changes' do
      UtilityCommands.new.invoke(:browser, nil, %w[:firefox])
      UtilityCommands.new.invoke(:headless, nil, %w[on])
      UtilityCommands.new.invoke(:viewport, nil, %w[1920x1080])
      UtilityCommands.new.invoke(:timeout, nil, %w[15])

      config = YAML.load_file('config/config.yml')
      expect(config['browser']).to eql 'firefox'
      expect(config['headless']).to be true
      expect(config['viewport']).to eq({ 'width' => 1920, 'height' => 1080 })
      expect(config['timeout']).to eq 15
    end

    it 'deletes browser arguments after setting them' do
      UtilityCommands.new.invoke(:browser, nil, %w[:firefox --opts headless])
      UtilityCommands.new.invoke(:browser, nil, %w[--delete])
      config = YAML.load_file('config/config.yml')
      expect(config.dig('browser_arguments', 'firefox')).to be_nil
    end
  end

  context 'with selenium + rspec' do
    include_examples 'updates browser config after creation', 'rspec', 'selenium'
  end

  context 'with selenium + cucumber' do
    include_examples 'updates browser config after creation', 'cucumber', 'selenium'
  end

  context 'with watir + rspec' do
    include_examples 'updates browser config after creation', 'rspec', 'watir'
  end

end
