# frozen_string_literal: true

require 'fileutils'
require 'rspec'
require_relative '../../lib/adopter/adopt_menu'

RSpec.describe Adopter::AdoptMenu do
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:source_dir) { 'tmp_adopt_interactive_source' }
  let(:output_dir) { 'tmp_adopt_interactive_output' }

  before do
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    allow(prompt).to receive(:say)
    allow(prompt).to receive(:warn)
    allow(prompt).to receive(:error)

    FileUtils.mkdir_p(source_dir)
    File.write("#{source_dir}/Gemfile", "gem 'rspec'\ngem 'selenium-webdriver'\n")
    FileUtils.mkdir_p("#{source_dir}/spec")
    File.write("#{source_dir}/spec/login_spec.rb", "describe 'Login' do\n  it('works') { expect(true).to be true }\nend\n")
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(output_dir)
  end

  describe '#run' do
    before do
      allow(prompt).to receive(:ask).and_return(source_dir, output_dir)
      allow(prompt).to receive(:select)
        .with('Select target automation framework:', anything, anything).and_return('Selenium')
      allow(prompt).to receive(:select)
        .with('Select target test framework:', anything, anything).and_return('Rspec')
      allow(prompt).to receive(:select)
        .with('Configure CI/CD?', anything, anything).and_return(nil)
    end

    it 'shows detection preview' do
      described_class.new.run

      expect(prompt).to have_received(:say).with(match(/Detected project settings/))
      expect(prompt).to have_received(:say).with(match(/Automation: selenium/))
      expect(prompt).to have_received(:say).with(match(/Framework:.*rspec/))
    end

    it 'executes adoption and shows results' do
      described_class.new.run

      expect(prompt).to have_received(:say).with(match(/Adoption complete/))
      expect(prompt).to have_received(:say).with(match(/Pages converted/))
      expect(prompt).to have_received(:say).with(match(/Tests converted/))
    end

    it 'generates the output project' do
      described_class.new.run

      expect(File).to exist("#{output_dir}/Gemfile")
    end

    it 'shows output path and bundle install instruction' do
      described_class.new.run

      expect(prompt).to have_received(:say).with(match(/Output: #{output_dir}/))
      expect(prompt).to have_received(:say).with(match(/bundle install/))
    end
  end

  describe '#run with mobile source project' do
    before do
      File.write("#{source_dir}/Gemfile", "gem 'rspec'\ngem 'appium_lib'\n")
      allow(prompt).to receive(:ask).and_return(source_dir, output_dir)
      allow(prompt).to receive(:select).and_return('Selenium', 'Rspec', nil)
    end

    it 'shows MobileProjectError message' do
      described_class.new.run

      expect(prompt).to have_received(:error).with(match(/Mobile.*Appium.*cannot be adopted/))
    end
  end

  describe 'validation constants' do
    it 'defines web automations' do
      expect(described_class::WEB_AUTOMATIONS).to contain_exactly('selenium', 'capybara', 'watir')
    end

    it 'defines test frameworks' do
      expect(described_class::TEST_FRAMEWORKS).to contain_exactly('rspec', 'cucumber', 'minitest')
    end

    it 'defines CI platforms' do
      expect(described_class::CI_PLATFORMS).to contain_exactly('github', 'gitlab')
    end
  end
end
