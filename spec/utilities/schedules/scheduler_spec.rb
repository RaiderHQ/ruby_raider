# frozen_string_literal: true

require 'json'
require 'rbconfig'
require 'stringio'
require 'tmpdir'
require 'yaml'
require_relative '../../../lib/utilities/schedules/scheduler'
require_relative '../../../lib/utilities/flows/schedule'

# The fake adapter, store and streams sit next to the project and scheduler
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::Scheduler do # rubocop:disable RSpec/FilePath
  # Stands in for an OS scheduler: records every call, keeps the installed os_ids; list_ids returns them plus
  # whatever `extra` holds, unfiltered, so the scheduler's own checks are what keeps noise out
  let(:fake_adapter) do
    Class.new do
      attr_reader :calls, :installed, :schedules, :extra
      attr_accessor :fail_present, :fail_list, :fail_remove, :note

      def initialize
        @calls = []
        @installed = []
        @schedules = []
        @extra = []
      end

      def label = 'fakeos'

      def install(schedule)
        @calls << [:install, schedule.os_id]
        @schedules << schedule
        @installed |= [schedule.os_id]
        true
      end

      def remove(os_id)
        @calls << [:remove, os_id]
        raise RubyRaider::Schedules::Error, 'launchctl refused' if fail_remove

        !@installed.delete(os_id).nil?
      end

      def present?(os_id)
        raise RubyRaider::Schedules::Error, 'task list unreadable' if fail_present

        @installed.include?(os_id)
      end

      def list_ids(_prefix)
        raise RubyRaider::Schedules::Error, 'task list unreadable' if fail_list

        @installed + @extra
      end

      def missed_runs_note = note
    end
  end

  let(:dir) { File.realpath(Dir.mktmpdir('schedules-scheduler')) }
  let(:project) { RubyRaider::Schedules::Project.new(dir) }
  let(:adapter) { fake_adapter.new }
  let(:store) { RubyRaider::Schedules::ScheduleStore.new(project) }
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  # Sun 8 Nov 2026 12:00 local
  let(:now) { Time.local(2026, 11, 8, 12, 0) }
  let(:host_os) { 'darwin25' }
  let(:scheduler) { described_class.new(project, adapter: adapter, store: store, out: out, err: err, now: -> { now }, host_os: host_os) }
  let(:os_id) { RubyRaider::Schedules::Schedule.os_id_for(dir, 'nightly') }
  let(:yml) { File.join(dir, '.raider/schedules/schedules.yml') }

  before do
    %w[spec/a_spec.rb spec/b_spec.rb].each do |file|
      FileUtils.mkdir_p(File.dirname(File.join(dir, file)))
      File.write(File.join(dir, file), '')
    end
    # add checks the project's bundle has `raider schedule`
    File.write(File.join(dir, 'Gemfile'), "gem 'ruby_raider'\n")
    File.write(File.join(dir, 'Gemfile.lock'), "GEM\n  specs:\n    ruby_raider (#{RubyRaider::Schedules::Project::OWN_VERSION})\n")
  end

  after { FileUtils.rm_rf(dir) }

  def add(name = 'nightly', every: 'day', at: '08:00', **options) = scheduler.add(name, every: every, at: at, **options)

  def log_run(name, *lines)
    file = File.join(dir, ".raider/schedules/#{name}/runs.jsonl")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, lines.map { |line| "#{JSON.generate(line)}\n" }.join, mode: 'a')
  end

  def edit_yml
    data = YAML.safe_load_file(yml)
    yield data['schedules']
    File.write(yml, YAML.dump(data))
  end

  def mode(relative) = File.stat(File.join(dir, relative)).mode & 0o777

  # What list prints, without what add printed before it
  def listed(json: true)
    out.truncate(0)
    out.rewind
    scheduler.list(json: json)
    json ? JSON.parse(out.string) : out.string
  end

  describe '.adapter' do
    let(:runner) { instance_double(RubyRaider::Schedules::Os::CommandRunner) }

    it 'picks launchd on macOS and Task Scheduler on Windows for test schedules, without calling them' do
      picked = %w[darwin25 mingw32].map { |host| described_class.adapter(runner: runner, host_os: host) }

      expect(picked.map(&:class)).to eq([RubyRaider::Schedules::Os::Launchd, RubyRaider::Schedules::Os::TaskScheduler])
      expect(picked.map { |item| item.instance_variable_get(:@kind) }).to all(be(RubyRaider::Schedules::Kind::TESTS))
    end

    it 'refuses another OS, also when add picks it lazily, before any folder is made' do
      expect { described_class.adapter(runner: runner, host_os: 'solaris2') }
        .to raise_error(RubyRaider::Schedules::Error, 'Scheduling tests is not supported on solaris2')

      lazy = described_class.new(project, out: out, err: err, now: -> { now }, host_os: 'solaris2')
      expect { lazy.add('nightly', every: 'day', at: '08:00') }
        .to raise_error(RubyRaider::Schedules::Error, 'Scheduling tests is not supported on solaris2')
      expect(File.exist?(File.join(dir, '.raider'))).to be(false)
    end
  end

  describe '#add' do
    it 'installs the OS entry, then writes the yml, ignores the folder in git and says when it next runs' do
      allow(store).to receive(:save).and_wrap_original do |original, schedule|
        expect(adapter.installed).to include(schedule.os_id)
        original.call(schedule)
      end

      add(every: 'weekday')

      expect(out.string).to eq("Scheduled nightly: every weekday at 08:00, next run Mon 08:00\n")
      expect([adapter.calls, store.find('nightly').selection.to_h]).to eq([[[:install, os_id]], { 'kind' => 'all' }])
      expect([File.read(File.join(dir, '.gitignore')), err.string]).to eq([".raider/schedules/\n", ''])
    end

    it 'says Replaced when the name already had a schedule, and keeps one entry' do
      add
      add(every: 'week', at: '09:30', on: 'wed', tag: 'smoke')

      expect(out.string.lines.last).to eq("Replaced nightly: every week on wed at 09:30, next run Wed 09:30\n")
      expect(store.all.map { |item| [item.rule_text, item.selection.to_h] }).to eq([['every week on wed at 09:30', { 'kind' => 'tag', 'tag' => 'smoke' }]])
    end

    it 'stores spec files, a tag, retries, notify and show_browser as given' do
      File.write(File.join(dir, 'helpers/driver_helper.rb').tap { |file| FileUtils.mkdir_p(File.dirname(file)) }, "require 'ruby_raider/runtime'\n")
      add('files', files: %w[spec/b_spec.rb spec/a_spec.rb], retries: 2, notify: true, show_browser: true)
      add('tagged', every: 'hour', at: ':15', tag: 'smoke')

      expect(store.all.map { |item| [item.name, item.selection.to_h, item.retries, item.notify, item.show_browser, item.at] })
        .to eq([['files', { 'kind' => 'files', 'files' => %w[spec/b_spec.rb spec/a_spec.rb] }, 2, true, true, '08:00'],
                ['tagged', { 'kind' => 'tag', 'tag' => 'smoke' }, 0, false, false, '00:15']])
      expect(out.string.lines.last).to eq("Scheduled tagged: every hour at :15, next run Sun 12:15\n")
    end

    it 'installs from a freshly built schedule, never from the ruby, bundle or gem env of the yml it replaces' do
      add
      edit_yml { |entries| entries.first.merge!('ruby' => '/evil/ruby', 'bundle' => '/evil/bundle', 'gem_env' => { 'GEM_HOME' => '/evil' }) }
      add

      installed = adapter.schedules.last
      expect([installed.ruby, installed.bundle, installed.gem_env]).to eq([RbConfig.ruby, RubyRaider::Schedules::Schedule.bundle_path,
                                                                           RubyRaider::Schedules::Schedule.captured_gem_env])
      expect(store.find('nightly').ruby).to eq(RbConfig.ruby)
    end

    it 'makes .raider/schedules and .raider/schedules/<name> 0700 folders' do
      add

      expect([mode('.raider/schedules'), mode('.raider/schedules/nightly'), mode('.raider/schedules/schedules.yml')]).to eq([0o700, 0o700, 0o600])
    end

    it 'removes the OS entry again when the yml cannot be written' do
      allow(store).to receive(:save).and_raise(RubyRaider::Schedules::Error, 'disk full')

      expect { add }.to raise_error(RubyRaider::Schedules::Error, 'disk full: the fakeos entry was removed too, so nightly is not scheduled')
      expect([adapter.calls, adapter.installed]).to eq([[[:install, os_id], [:remove, os_id]], []])
    end

    it 'says so when the rollback fails too' do
      allow(store).to receive(:save).and_raise(Errno::ENOSPC)
      adapter.fail_remove = true

      expect { add }.to raise_error(RubyRaider::Schedules::Error, /No space left on device.*\(and removing the fakeos entry failed: launchctl refused\)/)
    end

    context 'when refused before the OS scheduler or any file is touched' do
      def refused(message, **options)
        expect { scheduler.add(options.delete(:name) || 'nightly', every: 'day', at: '08:00', **options) }
          .to raise_error(RubyRaider::Schedules::Error, message)
        expect([adapter.calls, File.exist?(File.join(dir, '.raider')), File.exist?(File.join(dir, '.gitignore'))]).to eq([[], false, false])
      end

      it 'refuses a bad name' do
        ['Nightly', 'a' * 61, '../x', '', "a\nb"].each { |name| refused(/Invalid schedule name/, name: name) }
      end

      it 'refuses a missing, hostile or outside spec file, and a tag with files' do
        refused('spec/c_spec.rb not found', files: %w[spec/c_spec.rb])
        refused(/Invalid spec file/, files: ['../x_spec.rb'])
        refused(/Invalid spec file/, files: ['-rf_spec.rb'])
        refused('Use --tag or spec files, not both', files: %w[spec/a_spec.rb], tag: 'smoke')
        refused(/Invalid tag/, tag: '$(id)')
      end

      it 'refuses a project whose bundle has no raider schedule, after the other checks' do
        File.write(File.join(dir, 'Gemfile.lock'), "GEM\n  specs:\n    ruby_raider (4.0.1)\n")
        refused(/\AScheduling needs ruby_raider \S+ or later in this project: bundle update ruby_raider\z/)
        File.delete(File.join(dir, 'Gemfile.lock'))
        refused(/: run bundle install first\z/)
        refused(/Invalid every/, every: 'yearly')
      end

      it 'refuses a bad rule' do
        refused(/Invalid every/, every: 'yearly')
      end

      it 'refuses show_browser on Linux, before checking the project' do
        allow(project).to receive(:check_show_browser!)
        linux = described_class.new(project, adapter: adapter, store: store, out: out, err: err, now: -> { now }, host_os: 'linux-gnu')

        expect { linux.add('nightly', every: 'day', at: '08:00', show_browser: true) }
          .to raise_error(RubyRaider::Schedules::Error, "Show the browser isn't available for scheduled runs on Linux")
        expect([adapter.calls, File.exist?(File.join(dir, '.raider'))]).to eq([[], false])
        expect(project).not_to have_received(:check_show_browser!)
      end

      it 'refuses show_browser for a project made before 4.0' do
        refused('Show the browser needs a project made with Ruby Raider 4.0 or later', show_browser: true)
      end

      it 'refuses Windows-expanding file names on Windows' do
        File.write(File.join(dir, 'spec/a%PATH%_spec.rb'), '')
        windows = described_class.new(project, adapter: adapter, store: store, out: out, err: err, now: -> { now }, host_os: 'mingw32')

        expect { windows.add('nightly', every: 'day', at: '08:00', files: ['spec/a%PATH%_spec.rb']) }.to raise_error(RubyRaider::Schedules::Error)
        expect(adapter.calls).to eq([])
      end
    end

    it 'refuses a linked schedule folder before the OS scheduler is touched' do
      FileUtils.mkdir_p(File.join(dir, '.raider/schedules'))
      File.symlink(FileUtils.mkdir_p(File.join(dir, 'elsewhere')).first, File.join(dir, '.raider/schedules/nightly'))

      expect { add }.to raise_error(RubyRaider::Schedules::Error, '.raider/schedules/nightly must be a folder, not a link')
      expect(adapter.calls).to eq([])
    end

    it 'refuses a schedules.yml it can not rewrite before the OS scheduler is touched' do
      FileUtils.mkdir_p(File.dirname(yml))
      File.write(yml, "schedules: nope\n")

      expect { add }.to raise_error(RubyRaider::Schedules::Error, /not a schedules file/)
      expect(adapter.calls).to eq([])
    end

    it 'still schedules, with a warning, when .gitignore can not take the line' do
      target = File.join(dir, 'elsewhere_ignore')
      File.write(target, "keep\n")
      File.symlink(target, File.join(dir, '.gitignore'))

      add

      expect(out.string).to start_with('Scheduled nightly')
      expect(err.string).to eq("Could not add .raider/schedules/ to .gitignore: .gitignore is a link: add .raider/schedules/ to it yourself\n")
      expect([File.read(target), store.find('nightly').name]).to eq(%W[keep\n nightly])
    end

    it 'warns, and still schedules, when .gitignore can not be written' do
      allow(store).to receive(:ignore_in_git).and_raise(Errno::EACCES, '.gitignore')

      add

      expect([out.string.lines.size, err.string]).to eq([1, "Could not add .raider/schedules/ to .gitignore: Permission denied - .gitignore\n"])
    end
  end

  describe '#remove' do
    it 'removes the OS entry first, then the yml entry' do
      add
      allow(store).to receive(:delete).and_wrap_original do |original, name|
        expect(adapter.installed).to be_empty
        original.call(name)
      end

      scheduler.remove('nightly')

      expect([out.string.lines.last, store.find('nightly'), adapter.calls.last]).to eq(["Removed nightly\n", nil, [:remove, os_id]])
    end

    it 'says when the OS entry was already gone, and when only the OS entry was left' do
      add
      adapter.installed.clear
      scheduler.remove('nightly')
      adapter.installed << os_id
      scheduler.remove('nightly')

      expect(out.string.lines.last(2)).to eq(["Removed nightly (it was already gone from fakeos)\n", "Removed nightly\n"])
    end

    it 'refuses a name with no schedule, and a bad name without asking the OS' do
      expect { scheduler.remove('nightly') }.to raise_error(RubyRaider::Schedules::Error, 'No schedule nightly')
      expect { scheduler.remove('../x') }.to raise_error(RubyRaider::Schedules::Error, /Invalid schedule name/)
      expect(adapter.calls).to eq([[:remove, os_id]])
    end

    it 'keeps the yml entry when the OS scheduler refuses' do
      add
      adapter.fail_remove = true

      expect { scheduler.remove('nightly') }.to raise_error(RubyRaider::Schedules::Error, 'launchctl refused')
      expect(store.find('nightly')).not_to be_nil
    end

    it 'says the OS entry is gone when the yml can not be rewritten' do
      add
      allow(store).to receive(:delete).and_raise(RubyRaider::Schedules::Error, 'disk full')

      expect { scheduler.remove('nightly') }
        .to raise_error(RubyRaider::Schedules::Error, 'disk full: the fakeos entry was already removed, but schedules.yml still lists nightly')
    end

    it 'warns when the yml entry it removed could not be read' do
      add
      edit_yml { |entries| entries.first['every'] = 'yearly' }

      scheduler.remove('nightly')

      expect(err.string).to include('could not be read', 'fakeos entry made from a different project path may remain')
      expect(File.read(yml)).not_to include('nightly')
    end
  end

  describe '#list' do
    let(:zone) { Time.local(2026, 11, 9, 8, 0).strftime('%:z') }

    it 'is the JSON object with notice null and one row per schedule, in the spec shape' do
      add('all_tests', every: 'weekday')
      add('files', every: 'hour', at: ':15', files: %w[spec/a_spec.rb], retries: 1, notify: true)
      log_run('all_tests', { 'status' => 'failed', 'finished_at' => '2026-11-06T08:01:00Z', 'trigger' => 'schedule',
                             'counts' => { 'total' => 3, 'passed' => 2, 'failed' => 1, 'skipped' => 0 }, 'run_id' => 'x' },
              { 'status' => 'busy', 'finished_at' => '2026-11-07T08:00:00Z', 'trigger' => 'schedule' })

      expect(listed).to eq(
        'notice' => nil,
        'schedules' => [
          { 'name' => 'all_tests', 'every' => 'weekday', 'at' => '08:00', 'on' => nil, 'retries' => 0, 'notify' => false, 'show_browser' => false,
            'selection' => { 'kind' => 'all' }, 'next_run_at' => "2026-11-09T08:00:00#{zone}", 'os_state' => 'ok',
            'last' => { 'status' => 'failed', 'finished_at' => '2026-11-06T08:01:00Z', 'trigger' => 'schedule',
                        'counts' => { 'total' => 3, 'passed' => 2, 'failed' => 1, 'skipped' => 0 } } },
          { 'name' => 'files', 'every' => 'hour', 'at' => '00:15', 'on' => nil, 'retries' => 1, 'notify' => true, 'show_browser' => false,
            'selection' => { 'kind' => 'files', 'files' => %w[spec/a_spec.rb] }, 'next_run_at' => Time.local(2026, 11, 8, 12, 15).iso8601,
            'os_state' => 'ok', 'last' => nil }
        ]
      )
    end

    it 'gives each os_state, the file check before asking the OS' do
      %w[ok gone ruby file unknown].each { |name| add(name, files: %w[spec/a_spec.rb spec/b_spec.rb]) }
      adapter.installed.delete(RubyRaider::Schedules::Schedule.os_id_for(dir, 'gone'))
      edit_yml do |entries|
        entries.find { |entry| entry['name'] == 'ruby' }['ruby'] = File.join(dir, 'no_ruby')
        entries.find { |entry| entry['name'] == 'file' }['selection'] = { 'kind' => 'files', 'files' => %w[spec/a_spec.rb spec/gone_spec.rb spec/x_spec.rb] }
      end
      allow(adapter).to receive(:present?).and_wrap_original do |original, id|
        raise RubyRaider::Schedules::Error, "task list \xFFunreadable\e".dup.force_encoding(Encoding::UTF_8) if id.end_with?('.unknown')
        raise 'asked the OS for a schedule whose file is gone' if id.end_with?('.file')

        original.call(id)
      end

      expect(listed['schedules'].to_h { |row| [row['name'], row['os_state']] })
        .to eq('file' => 'test file not found: spec/gone_spec.rb', 'gone' => 'missing from fakeos', 'ok' => 'ok',
               'ruby' => 'Ruby not found: re-schedule', 'unknown' => 'unknown (task list ?unreadable?)')
    end

    it "adds a row for each of this project's OS entries that schedules.yml lacks, and ignores every other id" do
      add
      prefix = RubyRaider::Schedules::Schedule.os_id_prefix_for(dir)
      log_run('ghost', { 'status' => 'passed', 'finished_at' => 'f', 'trigger' => 'manual', 'counts' => {}, 'report_copy' => 'x' })
      adapter.extra.push("#{prefix}ghost", "#{prefix}ghost", RubyRaider::Schedules::Schedule.os_id_for('/elsewhere', 'stranger'),
                         RubyRaider::Flows::Schedule.os_id_for(dir, 'legacy'), "#{prefix}../../etc", "#{prefix}a;id", "#{prefix}Caps",
                         "#{prefix}a\xFF".dup.force_encoding(Encoding::UTF_8), nil)

      rows = listed['schedules']

      expect(rows.map { |row| row['name'] }).to eq(%w[nightly ghost])
      expect(rows.last).to eq('name' => 'ghost', 'every' => nil, 'at' => nil, 'on' => nil, 'retries' => nil, 'notify' => nil, 'show_browser' => nil,
                              'selection' => nil, 'next_run_at' => nil, 'os_state' => 'missing from schedules.yml',
                              'last' => { 'status' => 'passed', 'finished_at' => 'f', 'trigger' => 'manual', 'counts' => {} })
    end

    it 'lists only schedules.yml rows when the OS scheduler can not be enumerated' do
      add
      adapter.fail_list = true

      expect(listed['schedules'].map { |row| row['name'] }).to eq(%w[nightly])
    end

    it 'still lists, with unknown states, where there is no OS scheduler to ask' do
      add
      lazy = described_class.new(project, out: out, err: err, now: -> { now }, host_os: 'solaris2')
      out.truncate(0)
      out.rewind

      lazy.list

      expect(out.string).to end_with("never run  unknown (Scheduling tests is not supported on solaris2)\n")
      expect(out.string.lines.size).to eq(1)
    end

    it 'is an empty list, or the add hint as text, with no schedules' do
      expect(listed).to eq('notice' => nil, 'schedules' => [])
      expect(listed(json: false)).to eq("No schedules yet: raider schedule add <name> --every day --at 08:00\n")
    end

    it 'passes a notice through, in JSON and as the first text line' do
      scheduler.list(json: true, notice: 'Removed 1 flow schedule')
      scheduler.list(notice: 'Removed 1 flow schedule')

      expect(JSON.parse(out.string.lines.first)['notice']).to eq('Removed 1 flow schedule')
      expect(out.string.lines.drop(1)).to eq(["Removed 1 flow schedule\n", "No schedules yet: raider schedule add <name> --every day --at 08:00\n"])
    end

    it 'prints one printable line per row, then the missed runs note' do
      add('nightly', tag: 'smoke', notify: true)
      log_run('nightly', { 'status' => "passed\e[2J", 'finished_at' => '2026-11-07T08:01:00Z' })
      adapter.extra << RubyRaider::Schedules::Schedule.os_id_for(dir, 'ghost')
      adapter.note = '(cron: missed runs are skipped)'

      lines = listed(json: false).lines

      expect(lines[0]).to eq("#{'nightly'.ljust(30)}  tag smoke, every day at 08:00 (notify)  next Mon 9 Nov 08:00  passed?[2J  2026-11-07T08:01:00Z  ok\n")
      expect(lines[1]).to eq("#{'ghost'.ljust(30)}  -  -  never run  missing from schedules.yml\n")
      expect(lines[2..]).to eq(["(cron: missed runs are skipped)\n"])
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
