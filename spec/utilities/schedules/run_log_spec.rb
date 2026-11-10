# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/run_log'
require_relative '../../../lib/utilities/schedules/project'

RSpec.describe RubyRaider::Schedules::RunLog do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-log')) }
  let(:log) { described_class.new(RubyRaider::Schedules::Project.new(dir), 'nightly') }
  let(:folder) { File.join(dir, '.raider/schedules/nightly') }
  let(:file) { File.join(folder, 'runs.jsonl') }

  after { FileUtils.rm_rf(dir) }

  it 'appends one JSON line per run in a private folder' do
    log.append({ 'run_id' => 'a', 'status' => 'passed' })
    log.append({ 'run_id' => 'b', 'status' => 'failed' })

    expect(File.readlines(file).map { |line| JSON.parse(line)['run_id'] }).to eq(%w[a b])
    expect([File.stat(folder).mode & 0o777, File.stat(file).mode & 0o777]).to eq([0o700, 0o600])
    expect(log.find('a')['status']).to eq('passed')
  end

  it 'keeps the last 50 lines' do
    52.times { |n| log.append({ 'run_id' => n.to_s }) }

    ids = log.lines.map { |line| line['run_id'] }
    expect([ids.size, ids.first, ids.last]).to eq([50, '2', '51'])
    expect(Dir.children(folder)).to eq(['runs.jsonl'])
  end

  it 'refuses a linked log and leaves its target alone' do
    FileUtils.mkdir_p(folder)
    target = File.join(dir, 'target.jsonl')
    File.write(target, "keep\n")
    File.symlink(target, file)

    expect { log.append({ 'run_id' => 'a' }) }.to raise_error(RubyRaider::Schedules::Error, /runs.jsonl/)
    expect(File.read(target)).to eq("keep\n")
  end

  it 'refuses a linked schedule folder' do
    other = File.join(dir, 'elsewhere')
    FileUtils.mkdir_p([other, File.join(dir, '.raider/schedules')])
    File.symlink(other, folder)

    expect { log.append({ 'run_id' => 'a' }) }.to raise_error(RubyRaider::Schedules::Error, /not a link/)
    expect(Dir.children(other)).to eq([])
  end

  it 'reads a log of another kind from its own folder' do
    flow_log = File.join(dir, '.raider/flows/report/runs.jsonl')
    FileUtils.mkdir_p(File.dirname(flow_log))
    File.write(flow_log, %({"status":"completed"}\n))

    expect(described_class.new(RubyRaider::Schedules::Project.new(dir), 'report', dir: '.raider/flows').last['status']).to eq('completed')
  end
end
