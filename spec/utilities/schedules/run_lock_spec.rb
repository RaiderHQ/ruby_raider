# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative '../../../lib/utilities/schedules/run_lock'
require_relative '../../../lib/utilities/schedules/project'

# The lock, its folder and running.json sit next to the project they belong to
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::RunLock do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-lock')) }
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:lock) { described_class.new(project) }
  let(:folder) { File.join(dir, '.raider/schedules') }
  let(:running) { File.join(folder, 'running.json') }
  let(:lock_file) { File.join(folder, 'run.lock') }
  let(:started_at) { '2026-11-11T08:00:00.000Z' }

  after do
    lock.release
    FileUtils.rm_rf(dir)
  end

  def acquire = lock.acquire(name: 'nightly', run_id: 'r1', started_at: started_at)

  def dead_pid
    pid = Process.spawn(RbConfig.ruby, '-e', 'exit 0')
    Process.wait(pid)
    pid
  end

  def write_running(pid)
    FileUtils.mkdir_p(folder)
    File.write(running, JSON.generate('pid' => pid, 'name' => 'other', 'run_id' => 'x', 'started_at' => started_at))
  end

  it 'takes the lock and writes running.json for the desktop, private' do
    expect(acquire).to be(true)
    expect(JSON.parse(File.read(running))).to eq('pid' => Process.pid, 'name' => 'nightly', 'run_id' => 'r1', 'started_at' => started_at)
    expect([File.stat(running).mode & 0o777, File.stat(lock_file).mode & 0o777, File.stat(folder).mode & 0o777]).to eq([0o600, 0o600, 0o700])
  end

  it 'removes running.json and frees the lock on release, keeping run.lock' do
    acquire
    lock.release

    expect([File.exist?(running), File.exist?(lock_file)]).to eq([false, true])
    expect(described_class.new(project).acquire(name: 'nightly', run_id: 'r2', started_at: started_at)).to be(true)
  end

  it 'is busy while another run holds the lock, and writes nothing' do
    FileUtils.mkdir_p(folder)
    File.open(lock_file, File::RDWR | File::CREAT, 0o600) do |held|
      held.flock(File::LOCK_EX)

      expect(acquire).to be(false)
      expect(File.exist?(running)).to be(false)
    end
  end

  it 'is busy while running.json names a live process, and leaves that file alone' do
    write_running(Process.ppid)
    before = File.read(running)

    expect(acquire).to be(false)
    lock.release
    expect(File.read(running)).to eq(before)
  end

  it 'replaces a running.json whose process is gone' do
    write_running(dead_pid)

    expect(acquire).to be(true)
    expect(JSON.parse(File.read(running))['run_id']).to eq('r1')
  end

  [0, -1, 'abc', nil, Process.pid].each do |pid|
    it "treats a running.json with pid #{pid.inspect} as stale" do
      write_running(pid)

      expect(acquire).to be(true)
    end
  end

  it 'treats a running.json that is not JSON as stale' do
    FileUtils.mkdir_p(folder)
    File.write(running, 'not json')

    expect(acquire).to be(true)
  end

  it 'never follows a linked running.json' do
    FileUtils.mkdir_p(folder)
    target = File.join(dir, 'target.json')
    File.write(target, JSON.generate('pid' => Process.ppid))
    File.symlink(target, running)

    expect(acquire).to be(true)
    expect([File.symlink?(running), File.read(target)]).to eq([false, JSON.generate('pid' => Process.ppid)])
  end

  it 'refuses a linked run.lock' do
    FileUtils.mkdir_p(folder)
    File.write(File.join(dir, 'target.lock'), '')
    File.symlink(File.join(dir, 'target.lock'), lock_file)

    expect { acquire }.to raise_error(RubyRaider::Schedules::Error, /run.lock/)
  end

  it 'leaves a running.json that another run wrote after ours' do
    acquire
    File.write(running, JSON.generate('pid' => Process.ppid, 'run_id' => 'theirs'))
    lock.release

    expect(JSON.parse(File.read(running))['run_id']).to eq('theirs')
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
