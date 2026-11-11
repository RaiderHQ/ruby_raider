# frozen_string_literal: true

require 'stringio'
require 'tmpdir'
require_relative '../../lib/ruby_raider'
require_relative '../../lib/commands/schedule_commands'

# Runs in this process through RubyRaider::Raider.start, so the `raider schedule` subcommand path is the real
# one (thor 1.2.2). Every example stubs Scheduler.new and RunWrapper.new: nothing reaches the OS scheduler
# or spawns rspec.
RSpec.describe ScheduleCommands do
  let(:scheduler) { instance_double(RubyRaider::Schedules::Scheduler, add: nil, list: nil, remove: nil) }
  let(:wrapper) { instance_double(RubyRaider::Schedules::RunWrapper, run: 0) }
  let(:dir) { File.realpath(Dir.mktmpdir('schedule-commands')) }

  before do
    allow(RubyRaider::Schedules::Scheduler).to receive(:new).and_return(scheduler)
    allow(RubyRaider::Schedules::RunWrapper).to receive(:new).and_return(wrapper)
  end

  after { FileUtils.rm_rf(dir) }

  # [stdout, stderr, exit code or nil when the command did not exit]
  def raider(*args)
    out = StringIO.new
    err = StringIO.new
    stdout = $stdout
    stderr = $stderr
    $stdout = out
    $stderr = err
    code = begin
      RubyRaider::Raider.start(args)
      nil
    rescue SystemExit => e
      e.status
    ensure
      $stdout = stdout
      $stderr = stderr
    end
    [out.string, err.string, code]
  end

  def project_root
    satisfy { |project| project.root == dir }
  end

  describe 'add' do
    it 'takes the spec files and the options in any order' do
      raider('schedule', 'add', 'nightly', '--every', 'day', 'spec/a_spec.rb', '--show-browser', 'spec/b_spec.rb',
             '--project', dir)

      expect(scheduler).to have_received(:add).with('nightly', every: 'day', files: %w[spec/a_spec.rb spec/b_spec.rb],
                                                               tag: nil, at: nil, on: nil, retries: 0, notify: false,
                                                               show_browser: true)
      expect(RubyRaider::Schedules::Scheduler).to have_received(:new).with(project_root)
    end

    it 'passes --at, --on, --tag, --retries and --notify' do
      raider('schedule', 'add', 'smoke', '--tag', 'smoke', '--every', 'week', '--on', 'mon', '--at', '08:30',
             '--retries', '2', '--notify', '--project', dir)

      expect(scheduler).to have_received(:add).with('smoke', every: 'week', files: [], tag: 'smoke', at: '08:30',
                                                             on: 'mon', retries: 2, notify: true, show_browser: false)
    end

    it 'is reached through raider sc' do
      raider('sc', 'add', 'nightly', '--every', 'day', '--project', dir)

      expect(scheduler).to have_received(:add).with('nightly', hash_including(every: 'day', files: []))
    end

    it 'exits 2 with one stderr line when --every is left out' do
      # The real Scheduler refuses; its adapter is a double that fails on any call
      allow(RubyRaider::Schedules::Scheduler).to receive(:new).and_wrap_original do |original, project|
        original.call(project, adapter: instance_double(RubyRaider::Schedules::Os::Launchd), out: $stdout, err: $stderr)
      end

      out, err, code = raider('schedule', 'add', 'nightly', '--at', '08:00', '--project', dir)

      expect([out, err, code]).to eq(['', "Invalid every nil: use hour, day, weekday or week\n", 2])
    end

    it 'exits 2 with one stderr line when the project has no Gemfile, before the OS scheduler is touched' do
      allow(RubyRaider::Schedules::Scheduler).to receive(:new).and_wrap_original do |original, project|
        original.call(project, adapter: instance_double(RubyRaider::Schedules::Os::Launchd), out: $stdout, err: $stderr)
      end
      version = File.read(File.expand_path('../../lib/version', __dir__)).strip

      out, err, code = raider('schedule', 'add', 'nightly', '--every', 'day', '--at', '08:00', '--project', dir)

      expect([out, err, code]).to eq(['', "Scheduling needs ruby_raider #{version} or later in this project: no Gemfile found\n", 2])
      expect(File.exist?(File.join(dir, '.raider'))).to be(false)
    end
  end

  describe 'refusals' do
    it 'exits 2 with the error on one stderr line' do
      allow(scheduler).to receive(:remove).and_raise(RubyRaider::Schedules::Error, 'No schedule gone')

      out, err, code = raider('schedule', 'remove', 'gone', '--project', dir)

      expect([out, err, code]).to eq(['', "No schedule gone\n", 2])
    end

    it 'keeps a --project with a newline on one stderr line' do
      out, err, code = raider('schedule', 'list', '--project', "/nonexistent/a\nb")

      expect([out, err, code]).to eq(['', "Project folder not found: /nonexistent/a?b\n", 2])
      expect(RubyRaider::Schedules::Scheduler).not_to have_received(:new)
    end

    it 'exits 2 for an argument that is not valid UTF-8, through schedule and sc' do
      results = [raider('schedule', 'add', "a\xFF", '--every', 'day'), raider('sc', 'remove', "a\xFF")]

      expect(results).to all(eq(['', "Invalid argument \"a\\xFF\": use valid UTF-8\n", 2]))
      expect(RubyRaider::Schedules::Scheduler).not_to have_received(:new)
    end
  end

  describe 'list and remove' do
    it 'lists as text, or as JSON with --json' do
      raider('schedule', 'list', '--project', dir)
      raider('schedule', 'list', '--json', '--project', dir)

      expect(scheduler).to have_received(:list).with(json: false).ordered
      expect(scheduler).to have_received(:list).with(json: true).ordered
    end

    it 'removes by name' do
      raider('schedule', 'remove', 'nightly', '--project', dir)

      expect(scheduler).to have_received(:remove).with('nightly')
    end
  end

  describe 'run' do
    it 'maps run to the wrapper with the manual trigger by default' do
      _out, _err, code = raider('schedule', 'run', 'nightly', '--project', dir)

      expect(code).to eq(0)
      expect(wrapper).to have_received(:run).with('nightly', trigger: 'manual')
      expect(RubyRaider::Schedules::RunWrapper).to have_received(:new).with(project_root)
    end

    it "exits with the wrapper's code and passes --trigger" do
      codes = [1, 2, 3].map do |status|
        allow(wrapper).to receive(:run).and_return(status)
        raider('sc', 'run', 'nightly', '--trigger', 'schedule', '--project', dir).last
      end

      expect(codes).to eq([1, 2, 3])
      expect(wrapper).to have_received(:run).with('nightly', trigger: 'schedule').exactly(3).times
    end

    it 'exits 2 with one stderr line when the wrapper refuses' do
      allow(wrapper).to receive(:run).and_raise(RubyRaider::Schedules::Error, 'Invalid trigger "x": use manual or schedule')

      out, err, code = raider('schedule', 'run', 'nightly', '--trigger', 'x', '--project', dir)

      expect([out, err, code]).to eq(['', "Invalid trigger \"x\": use manual or schedule\n", 2])
    end
  end

  describe 'help' do
    it 'lists the four commands in raider help schedule' do
      out, = raider('help', 'schedule')

      expect(out).to include('schedule add NAME [SPEC_FILE ...]', 'schedule list', 'schedule remove NAME',
                             'schedule run NAME')
    end

    # Thor would also reach run_schedule from `run` by prefix; the map is what keeps `run` working if that changes
    it 'maps run to run_schedule explicitly and shows it as run NAME' do
      out, = raider('help', 'schedule')

      expect(described_class.map).to include('run' => :run_schedule)
      expect(out).to match(/^ +\S+ schedule run NAME +# Runs the schedule NAME now/)
    end

    it 'lists schedule in raider help' do
      out, = raider('help')

      expect(out).to include('schedule', 'Runs the tests on a schedule')
    end
  end
end
