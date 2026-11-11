# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/schedules/schedule_store'

RSpec.describe RubyRaider::Schedules::ScheduleStore do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-store')) }
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:store) { described_class.new(project) }
  let(:file) { File.join(dir, '.raider/schedules/schedules.yml') }
  let(:gitignore) { File.join(dir, '.gitignore') }

  before do
    FileUtils.mkdir_p(File.join(dir, 'spec'))
    File.write(File.join(dir, 'spec/a_spec.rb'), '')
  end

  after { FileUtils.rm_rf(dir) }

  def schedule(name, **options)
    RubyRaider::Schedules::Schedule.build(project: project, name: name, every: 'day', at: '08:00', host_os: 'darwin24', **options)
  end

  def files(*names) = RubyRaider::Schedules::Selection.parse(files: names, tag: nil, root: dir, host_os: 'darwin24')

  it 'saves to .raider/schedules/schedules.yml, 0600 in a 0700 folder, sorted, and reads it back' do
    store.save(schedule('zeta', selection: files('spec/a_spec.rb'), show_browser: true))
    store.save(schedule('alpha'))

    expect([store.all.map(&:name), store.find('zeta').selection.files, store.find('zeta').show_browser]).to eq([%w[alpha zeta], %w[spec/a_spec.rb], true])
    expect([File.stat(file).mode & 0o777, File.stat(File.dirname(file)).mode & 0o777]).to eq([0o600, 0o700])
    expect(YAML.safe_load_file(file)['schedules'].last['selection']).to eq({ 'kind' => 'files', 'files' => %w[spec/a_spec.rb] })
  end

  it 'still lists a schedule whose spec file is gone' do
    store.save(schedule('nightly', selection: files('spec/a_spec.rb')))
    File.delete(File.join(dir, 'spec/a_spec.rb'))

    expect(store.find('nightly').selection.missing_file(dir)).to eq('spec/a_spec.rb')
  end

  it 'skips an entry that fails re-validation and keeps it when it writes' do
    FileUtils.mkdir_p(File.dirname(file))
    hostile = schedule('bad').to_h.merge('selection' => { 'kind' => 'files', 'files' => ['../x_spec.rb'] })
    File.write(file, { 'schedules' => [hostile, 'junk'] }.to_yaml)
    store.save(schedule('nightly'))

    expect([store.all.map(&:name), YAML.safe_load_file(file)['schedules'].size]).to eq([%w[nightly], 3])
  end

  it 'refuses to overwrite a file that is not a schedules file' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, "schedules: [\n")

    expect { store.save(schedule('nightly')) }
      .to raise_error(RubyRaider::Schedules::Error, '.raider/schedules/schedules.yml is not a schedules file: fix or remove it, then try again')
    expect(File.read(file)).to eq("schedules: [\n")
  end

  it 'refuses a linked schedules folder' do
    FileUtils.mkdir_p(File.join(dir, 'elsewhere'))
    FileUtils.mkdir_p(File.join(dir, '.raider'))
    File.symlink(File.join(dir, 'elsewhere'), File.join(dir, '.raider/schedules'))

    expect { store.save(schedule('nightly')) }.to raise_error(RubyRaider::Schedules::Error, '.raider/schedules must be a folder, not a link')
  end

  it 'does not load Ruby objects' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, "--- !ruby/object:OpenStruct\ntable: {}\n")

    expect(store.all).to eq([])
  end

  it 'returns the name and test os_id of an entry it removed but could not read' do
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, { 'schedules' => [{ 'name' => 'nightly' }] }.to_yaml)
    removed = store.delete('nightly')

    expect([removed.name, removed.os_id]).to eq(['nightly', RubyRaider::Schedules::Schedule.os_id_for(dir, 'nightly')])
  end

  describe '#ignore_in_git' do
    it 'creates .gitignore with the line when there is none' do
      expect([store.ignore_in_git, File.read(gitignore)]).to eq([true, ".raider/schedules/\n"])
    end

    it 'appends the line, keeping every byte and adding a newline first when the file lacks one' do
      File.binwrite(gitignore, "node_modules/\r\n\xFFraw")

      expect([store.ignore_in_git, File.binread(gitignore)]).to eq([true, "node_modules/\r\n\xFFraw\n.raider/schedules/\n".b])
    end

    it 'leaves the file alone when the exact line is there, and only adds it once' do
      File.write(gitignore, "a/\n.raider/schedules/\r\nb/")
      before = File.binread(gitignore)

      expect([store.ignore_in_git, File.binread(gitignore)]).to eq([false, before])
    end

    it 'adds the line when only a comment, a longer line or a prefix mentions it' do
      File.write(gitignore, "# .raider/schedules/\n.raider/schedules/x\n.raider/\n")
      first = store.ignore_in_git

      expect([first, store.ignore_in_git, File.read(gitignore).lines.last]).to eq([true, false, ".raider/schedules/\n"])
    end

    it 'refuses a .gitignore that is not a file' do
      FileUtils.mkdir_p(gitignore)

      expect { store.ignore_in_git }.to raise_error(RubyRaider::Schedules::Error, '.gitignore must be a file')
    end

    it 'refuses a linked .gitignore and never writes through it' do
      target = File.join(File.realpath(Dir.mktmpdir('outside')), 'ignored')
      File.write(target, "keep\n")
      File.symlink(target, gitignore)

      expect { store.ignore_in_git }.to raise_error(RubyRaider::Schedules::Error, '.gitignore is a link: add .raider/schedules/ to it yourself')
      expect([File.read(target), File.symlink?(gitignore)]).to eq(["keep\n", true])
    ensure
      FileUtils.rm_rf(File.dirname(target))
    end

    it 'refuses a dangling .gitignore link without making its target' do
      target = File.join(dir, 'made_by_the_link')
      File.symlink(target, gitignore)

      expect { store.ignore_in_git }.to raise_error(RubyRaider::Schedules::Error, /is a link/)
      expect(File.exist?(target)).to be(false)
    end

    it 'leaves a read-only .gitignore that has the line alone, and says so when it lacks it' do
      File.write(gitignore, ".raider/schedules/\n")
      File.chmod(0o444, gitignore)
      expect(store.ignore_in_git).to be(false)

      File.chmod(0o644, gitignore)
      File.write(gitignore, "a/\n")
      File.chmod(0o444, gitignore)
      expect { store.ignore_in_git }.to raise_error(Errno::EACCES)
      expect(File.read(gitignore)).to eq("a/\n")
    end

    it 'refuses a .gitignore that is a FIFO without blocking' do
      File.mkfifo(gitignore)

      expect { store.ignore_in_git }.to raise_error(RubyRaider::Schedules::Error, '.gitignore must be a file')
    end
  end
end
