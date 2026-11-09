# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/flows/run_log'
require_relative '../../../lib/utilities/flows/project'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::RunLog do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('flows-log')) }
  let(:log) { described_class.new(RubyRaider::Flows::Project.new(dir), 'report') }
  let(:file) { File.join(dir, '.raider/flows/report/runs.jsonl') }

  before { FileUtils.mkdir_p(File.dirname(file)) }

  after { FileUtils.rm_rf(dir) }

  it 'skips broken and non-object lines' do
    File.write(file, %({"status":"failed"}\nnot json\n[1]\n{"status":"completed","run_id":"a"}\n))

    expect([log.lines.size, log.last['status'], log.find('a')['status']]).to eq([2, 'completed', 'completed'])
  end

  it 'reads only the last megabyte of a big log, from a whole line' do
    File.write(file, %({"status":"old","pad":"#{'x' * 2_000_000}"}\n{"status":"completed"}\n))

    expect(log.lines).to eq([{ 'status' => 'completed' }])
  end

  it 'does not follow a linked log' do
    File.write(File.join(dir, 'other.jsonl'), %({"status":"completed"}\n))
    File.symlink(File.join(dir, 'other.jsonl'), file)

    expect(log.lines).to eq([])
  end

  it 'is empty without a log' do
    expect(log.last).to be_nil
  end
end
