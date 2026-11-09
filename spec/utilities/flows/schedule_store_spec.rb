# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/flows/schedule_store'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::ScheduleStore do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('flows-store')) }
  let(:project) { RubyRaider::Flows::Project.new(dir) }
  let(:store) { described_class.new(project) }
  let(:file) { File.join(dir, '.raider/flows/schedules.yml') }

  def schedule(name, at = '08:00')
    RubyRaider::Flows::Schedule.build(project: project, name: name, every: 'day', at: at)
  end

  after { FileUtils.rm_rf(dir) }

  it 'is empty without a file' do
    expect([store.all, store.find('report')]).to eq([[], nil])
  end

  it 'saves entries sorted by name and reads them back' do
    %w[zeta alpha mid].each { |name| store.save(schedule(name)) }

    expect([store.all.map(&:name), YAML.safe_load_file(file)['schedules'].map { |entry| entry['name'] }]).to eq([%w[alpha mid zeta]] * 2)
  end

  it 'replaces an entry by name' do
    store.save(schedule('report'))
    store.save(schedule('report', '09:30'))

    expect([store.all.size, store.find('report').at]).to eq([1, '09:30'])
  end

  it 'deletes every entry with the name, and returns the name and os_id of one it could not read' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, { 'schedules' => [{ 'name' => 'report', 'every' => 'yearly' }, { 'name' => 'report' }, schedule('other').to_h] }.to_yaml)
    removed = store.delete('report')

    expect([removed.class, removed.name, removed.os_id]).to eq([described_class::Removed, 'report', RubyRaider::Flows::Schedule.os_id_for(dir, 'report')])
    expect(YAML.safe_load_file(file)['schedules'].map { |entry| entry['name'] }).to eq(%w[other])
  end

  it 'returns the readable schedule when a broken entry shares its name' do
    store.save(schedule('report'))
    entries = YAML.safe_load_file(file)['schedules']
    File.write(file, { 'schedules' => [{ 'name' => 'report' }, *entries] }.to_yaml)

    expect([store.delete('report').class, store.all]).to eq([RubyRaider::Flows::Schedule, []])
  end

  it 'deletes an entry and returns it, or nil when it is not there' do
    store.save(schedule('report'))

    expect([store.delete('report').name, store.delete('report'), store.all]).to eq(['report', nil, []])
  end

  it 'skips invalid entries and keeps them when it writes' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, { 'schedules' => [{ 'name' => 'broken', 'every' => 'yearly' }, 'junk'] }.to_yaml)
    store.save(schedule('report'))

    expect([store.all.map(&:name), YAML.safe_load_file(file)['schedules'].size]).to eq([%w[report], 3])
  end

  it 'reads a file that is not YAML as empty but will not overwrite it' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, "schedules: [\n")

    expect(store.all).to eq([])
    expect { store.save(schedule('report')) }.to raise_error(RubyRaider::Flows::Error, /schedules.yml/)
    expect { store.delete('report') }.to raise_error(RubyRaider::Flows::Error, /schedules.yml/)
    expect(File.read(file)).to eq("schedules: [\n")
  end

  it 'will not overwrite a file it cannot read' do
    store.save(schedule('report'))
    before = File.read(file)
    File.chmod(0o000, file)

    expect(store.all).to eq([])
    expect { store.save(schedule('other')) }.to raise_error(RubyRaider::Flows::Error, /schedules.yml/)
    File.chmod(0o600, file)
    expect(File.read(file)).to eq(before)
  end

  it 'does not load Ruby objects' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, "--- !ruby/object:OpenStruct\ntable: {}\n")

    expect(store.all).to eq([])
  end

  it 'writes through a temp file and a rename in the same folder' do
    allow(File).to receive(:rename).and_call_original
    store.save(schedule('report'))

    expect(File).to have_received(:rename).with(%r{\A#{Regexp.escape(File.dirname(file))}/}, file)
    expect(Dir.children(File.dirname(file))).to eq(['schedules.yml'])
  end

  it 'makes the flows folder private' do
    store.save(schedule('report'))

    expect(File.stat(File.dirname(file)).mode & 0o777).to eq(0o700)
  end

  it 'refuses a linked flows folder' do
    FileUtils.mkdir_p(File.join(dir, 'elsewhere'))
    FileUtils.mkdir_p(File.join(dir, '.raider'))
    File.symlink(File.join(dir, 'elsewhere'), File.join(dir, '.raider/flows'))

    expect { store.save(schedule('report')) }.to raise_error(RubyRaider::Flows::Error, /not a link/)
  end

  it 'does not read or replace a linked schedules file' do
    FileUtils.mkdir_p(File.dirname(file))
    target = File.join(dir, 'other.yml')
    File.write(target, { 'schedules' => [schedule('report').to_h] }.to_yaml)
    before = File.read(target)
    File.symlink(target, file)

    expect(store.all).to eq([])
    expect { store.save(schedule('other')) }.to raise_error(RubyRaider::Flows::Error, /schedules.yml/)
    expect([File.symlink?(file), File.read(target)]).to eq([true, before])
  end
end
