# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/run_report'
require_relative '../../../lib/utilities/schedules/project'

RSpec.describe RubyRaider::Schedules::RunReport do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-report')) }
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:results) { File.join(dir, 'raider-results') }
  let(:spawned_at) { Time.utc(2026, 11, 11, 8, 0, 0) }
  let(:last) { File.join(dir, '.raider/schedules/nightly/last') }

  before { FileUtils.mkdir_p(File.join(dir, '.raider/schedules/nightly')) }

  after { FileUtils.rm_rf(dir) }

  def write_run(statuses, started_at: '2026-11-11T08:00:01.000Z')
    FileUtils.mkdir_p(results)
    run = started_at ? { 'started_at' => started_at } : {}
    File.write(File.join(results, 'run.json'), JSON.generate('run' => run, 'results' => statuses.map { |status| { 'status' => status } }))
  end

  def load = described_class.load(project, since: spawned_at)

  it 'counts results: quarantined as failed, pending as skipped' do
    write_run(%w[passed failed quarantined pending skipped passed])

    expect(load.counts).to eq('total' => 6, 'passed' => 2, 'failed' => 2, 'skipped' => 2)
  end

  it 'is nil without a run.json' do
    expect(load).to be_nil
  end

  it 'ignores a run.json left by an earlier run' do
    write_run(%w[passed], started_at: '2026-11-11T07:00:00.000Z')

    expect(load).to be_nil
  end

  it 'accepts a run that started up to 2 s before the spawn' do
    write_run(%w[passed], started_at: '2026-11-11T07:59:58.500Z')

    expect(load.counts['total']).to eq(1)
  end

  it 'falls back to the file time when run.json has no start time' do
    write_run(%w[passed], started_at: nil)
    file = File.join(results, 'run.json')
    File.utime(spawned_at + 5, spawned_at + 5, file)
    fresh = load

    File.utime(spawned_at - 1, spawned_at - 1, file)
    slack = load
    File.utime(spawned_at - 60, spawned_at - 60, file)

    expect([fresh&.counts&.fetch('total'), slack&.counts&.fetch('total'), load]).to eq([1, 1, nil])
  end

  it 'is nil for a run.json that is not a report' do
    FileUtils.mkdir_p(results)
    ['not json', '[1]', '{"results":"x"}'].each do |text|
      File.write(File.join(results, 'run.json'), text)
      expect(load).to be_nil
    end
  end

  it 'never follows a linked run.json or results folder' do
    other = File.join(dir, 'other')
    FileUtils.mkdir_p(other)
    File.write(File.join(other, 'run.json'), JSON.generate('run' => { 'started_at' => '2026-11-11T08:00:01Z' }, 'results' => []))
    File.symlink(other, results)
    linked_folder = load
    FileUtils.rm(results)
    FileUtils.mkdir_p(results)
    File.symlink(File.join(other, 'run.json'), File.join(results, 'run.json'))

    expect([linked_folder, load]).to eq([nil, nil])
  end

  describe '#copy_to' do
    before do
      write_run(%w[passed])
      File.write(File.join(results, 'index.html'), '<html>')
      FileUtils.mkdir_p(File.join(results, 'attachments/sub'))
      File.write(File.join(results, 'attachments/0-shot.png'), 'png')
      File.write(File.join(results, 'attachments/sub/trace.zip'), 'zip')
    end

    it 'copies run.json, index.html and the attachments, replacing the last copy' do
      FileUtils.mkdir_p(last)
      File.write(File.join(last, 'old.txt'), 'old')

      expect(load.copy_to(last)).to be(true)
      expect(Dir.glob('**/*', base: last).sort).to eq(%w[attachments attachments/0-shot.png attachments/sub attachments/sub/trace.zip index.html run.json])
      expect(File.read(File.join(last, 'attachments/sub/trace.zip'))).to eq('zip')
      expect(Dir.children(File.dirname(last))).to eq(['last'])
      expect(File.stat(last).mode & 0o777).to eq(0o700)
    end

    it 'leaves out the attachments when there are too many files or folders too deep' do
      stub_const("#{described_class}::MAX_ATTACHMENT_FILES", 1)
      load.copy_to(last)
      many = Dir.children(last).sort
      FileUtils.rm_rf(last)
      stub_const("#{described_class}::MAX_ATTACHMENT_FILES", 1000)
      stub_const("#{described_class}::MAX_ATTACHMENT_DEPTH", 0)
      load.copy_to(last)

      expect([many, Dir.children(last).sort]).to eq([%w[index.html run.json], %w[index.html run.json]])
    end

    it 'copies no more of a file than was counted for it' do
      target = File.join(dir, 'copy.png')
      load.send(:copy_file, File.join(results, 'attachments/0-shot.png'), target, 2)

      expect(File.read(target)).to eq('pn')
    end

    it 'leaves out the attachments when they are over the cap' do
      stub_const("#{described_class}::MAX_ATTACHMENT_BYTES", 5)

      load.copy_to(last)

      expect(Dir.children(last).sort).to eq(%w[index.html run.json])
    end

    it 'copies regular files only, never what a link points at' do
      secret = File.join(dir, 'secret.txt')
      File.write(secret, 'secret')
      File.symlink(secret, File.join(results, 'attachments/leak.txt'))
      File.symlink(File.dirname(secret), File.join(results, 'attachments/leakdir'))
      FileUtils.rm(File.join(results, 'index.html'))
      File.symlink(secret, File.join(results, 'index.html'))

      load.copy_to(last)

      expect(Dir.glob('**/*', base: last).sort).to eq(%w[attachments attachments/0-shot.png attachments/sub attachments/sub/trace.zip run.json])
    end

    it 'leaves raider-results as it was' do
      before = Dir.glob('**/*', base: results).sort.to_h { |path| [path, File.file?(File.join(results, path)) && File.read(File.join(results, path))] }
      load.copy_to(last)

      expect(Dir.glob('**/*', base: results).sort.to_h { |path| [path, File.file?(File.join(results, path)) && File.read(File.join(results, path))] }).to eq(before)
    end
  end
end
