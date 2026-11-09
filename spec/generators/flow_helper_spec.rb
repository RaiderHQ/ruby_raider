# frozen_string_literal: true

require 'erb'

# The flow templates are copied into projects by `raider flow init`
RSpec.describe 'flow templates' do
  let(:templates) { File.expand_path('../../lib/generators/templates', __dir__) }
  let(:helper) { render('flows/flow_helper.tt') }

  def render(relative) = ERB.new(File.read(File.join(templates, relative)), trim_mode: '-').result

  it 'starts the run before loading spec_helper, so the lock and HEADLESS come before the driver' do
    expect(helper.index('RaiderFlows::Run.start!')).to be < helper.index("require_relative '../helpers/spec_helper'")
  end

  it 'sends the report to the flow results folder without cleaning it' do
    expect(helper).to include('reporter.output_dir = RaiderFlows::Run.results_dir', 'reporter.clean_output_dir = false')
  end

  it 'marks the start of the steps after spec_helper set up the driver' do
    expect(helper).to include('config.append_before(:each) { RaiderFlows::Run.steps_started! }')
  end

  it 'never sets the reporter output folder from spec_helper, so a test run cannot wipe flow results' do
    spec_helper = File.read(File.join(templates, 'helpers/spec_helper.tt'))

    expect(spec_helper).not_to match(/output_dir|clean_output_dir/)
  end

  it 'renders Ruby that parses' do
    [helper, render('flows/run.tt')].each do |source|
      expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
    end
  end
end
