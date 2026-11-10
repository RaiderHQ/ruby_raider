# frozen_string_literal: true

require 'tmpdir'
require 'digest'
require_relative '../../../lib/utilities/schedules/schedule'

RSpec.describe RubyRaider::Schedules::Schedule do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('schedules-schedule')) }
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }
  let(:mac) { 'darwin24' }

  before do
    FileUtils.mkdir_p(File.join(dir, 'spec'))
    File.write(File.join(dir, 'spec/a_spec.rb'), '')
  end

  after { FileUtils.rm_rf(dir) }

  def build(**options)
    described_class.build(project: project, name: 'nightly', every: 'day', at: '08:00', now: now, host_os: mac, **options)
  end

  def error_for(**options)
    build(**options)
    nil
  rescue RubyRaider::Schedules::Error => e
    e.message
  end

  def files(*names) = RubyRaider::Schedules::Selection.parse(files: names, tag: nil, root: dir, host_os: mac)

  it 'keeps every field of the entry, with all tests by default' do
    schedule = build(every: 'week', on: 'tue', retries: 2, notify: true, show_browser: true)
    hash = schedule.to_h

    expect(hash.keys).to eq(%w[name every at on retries notify show_browser selection os_id ruby bundle gem_env created_at])
    expect(hash.slice('name', 'every', 'at', 'on', 'retries', 'notify', 'show_browser', 'selection', 'created_at'))
      .to eq({ 'name' => 'nightly', 'every' => 'week', 'at' => '08:00', 'on' => 'tue', 'retries' => 2, 'notify' => true,
               'show_browser' => true, 'selection' => { 'kind' => 'all' }, 'created_at' => '2026-11-09T10:00:00Z' })
  end

  it 'names the os_id after the project and the name' do
    expect(build.os_id).to eq("dev.rubyraider.schedule.#{Digest::SHA256.hexdigest(dir)[0, 10]}.nightly")
  end

  it 'runs raider schedule run NAME and nothing else from the OS entry' do
    schedule = build(retries: 3, notify: true, show_browser: true, selection: files('spec/a_spec.rb'))

    expect(schedule.argv).to eq([schedule.ruby, schedule.bundle, 'exec', 'raider', 'schedule', 'run', 'nightly', '--project', dir, '--trigger', 'schedule'])
  end

  it 'logs the scheduler output under .raider/schedules and keeps the 4.1 env' do
    schedule = build

    expect([schedule.log_path, schedule.env.keys.first(2), schedule.working_directory])
      .to eq([File.join(dir, '.raider/schedules/nightly/scheduler.log'), %w[PATH LANG], dir])
  end

  it 'refuses show_browser on Linux and nowhere else' do
    expect([error_for(show_browser: true, host_os: 'x86_64-linux-gnu'), error_for(show_browser: false, host_os: 'x86_64-linux-gnu'),
            error_for(show_browser: true, host_os: 'mingw32')])
      .to eq(["Show the browser isn't available for scheduled runs on Linux", nil, nil])
  end

  it 'refuses a bad name, show_browser or selection' do
    errors = [error_for(name: 'Nightly'), error_for(name: 'a' * 61), error_for(show_browser: 'yes'), error_for(selection: { 'kind' => 'all' })]

    expect(errors).to eq(['Invalid schedule name "Nightly": use 1 to 60 of a-z, 0-9 and _', "Invalid schedule name \"#{'a' * 61}\": use 1 to 60 of a-z, 0-9 and _",
                          'Invalid show_browser "yes": use true or false', 'Invalid selection: use a Selection'])
  end

  it 'shares the rule checks with flow schedules' do
    expect([error_for(every: 'month'), error_for(at: '8:00'), error_for(retries: 4), error_for(notify: 'yes')])
      .to eq(['Invalid every "month": use hour, day, weekday or week', 'Invalid at "8:00": use HH:MM (24h)',
              'Invalid retries 4: use 0 to 3', 'Invalid notify "yes": use true or false'])
  end

  describe '.from_h' do
    it 'reads back what to_h wrote' do
      schedule = build(selection: files('spec/a_spec.rb'), show_browser: true)

      expect(described_class.from_h(schedule.to_h, dir, host_os: mac).to_h).to eq(schedule.to_h)
    end

    it 'loads an entry whose spec file is gone' do
      hash = build(selection: files('spec/a_spec.rb')).to_h
      File.delete(File.join(dir, 'spec/a_spec.rb'))

      expect(described_class.from_h(hash, dir, host_os: mac).selection.missing_file(dir)).to eq('spec/a_spec.rb')
    end

    it 'treats an entry without show_browser as off' do
      expect(described_class.from_h(build.to_h.except('show_browser'), dir, host_os: mac).show_browser).to be(false)
    end

    it 'refuses an entry from another project, a flow entry, a broken selection or a non-mapping' do
      other = File.realpath(Dir.mktmpdir('schedules-other'))
      flow = build.to_h.merge('os_id' => build.os_id.sub('.schedule.', '.flow.'))
      entries = [[build.to_h, other], [flow, dir], [build.to_h.merge('selection' => { 'kind' => 'tag', 'tag' => 'a;b' }), dir],
                 [build.to_h.except('selection'), dir], ['nightly', dir]]
      errors = entries.map do |hash, root|
        described_class.from_h(hash, root, host_os: mac)
        nil
      rescue RubyRaider::Schedules::Error => e
        e.message
      end

      expect(errors).to all(be_a(String))
    ensure
      FileUtils.rm_rf(other)
    end
  end

  it 'is frozen' do
    schedule = build(selection: files('spec/a_spec.rb'))

    expect([schedule, schedule.selection, schedule.name]).to all(be_frozen)
  end
end
