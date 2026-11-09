# frozen_string_literal: true

require 'open3'
require_relative '../../lib/ruby_raider'

RSpec.describe FlowCommands do
  let(:raider_bin) { File.expand_path('../../bin/raider', __dir__) }

  def run_raider(*args)
    Open3.capture3(RbConfig.ruby, raider_bin, *args)
  end

  it 'lists init, run and list in raider flow help' do
    out, _err, status = run_raider('flow', 'help')

    expect(status.exitstatus).to eq(0)
    expect(out).to include('flow init', 'flow run NAME', 'flow list')
  end

  it 'maps raider f to the flow commands' do
    out, _err, status = run_raider('f', 'help')

    expect(status.exitstatus).to eq(0)
    expect(out).to include('flow run NAME')
  end

  it 'is listed in raider help' do
    out, = run_raider('help')

    expect(out).to include('raider flow')
  end
end
