# frozen_string_literal: true

require 'stringio'
require 'tmpdir'
require_relative '../../../lib/ruby_raider'
require_relative '../../../lib/utilities/schedules/legacy_stub'
require_relative '../../../lib/utilities/schedules/notifier'

# Through RubyRaider::Raider.start, as `raider flow ...` from a 4.1 OS entry reaches it. Legacy always gets a
# recording adapter: nothing reaches the OS scheduler.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe RubyRaider::Schedules::LegacyStub do # rubocop:disable RSpec/FilePath
  let(:fake_adapter_class) do
    Class.new do
      attr_reader :ids, :removed

      def initialize(ids)
        @ids = ids
        @removed = []
      end

      def list_ids(prefix) = ids.select { |id| id.start_with?(prefix) }

      def remove(os_id)
        @removed << os_id.split('.').last
        true
      end
    end
  end
  let(:dir) { File.realpath(Dir.mktmpdir('legacy-stub')) }
  let(:adapter) { fake_adapter_class.new(%w[other tredssd].map { |name| os_id(name) }) }
  let(:removed_line) { 'This command was removed in Ruby Raider 4.2. To run tests on a schedule, use raider schedule add.' }
  let(:notice) do
    "Removed 2 schedules made with Ruby Raider 4.1 (other, tredssd); they can't run in 4.2. Add them again with raider schedule add."
  end

  before do
    File.write(File.join(dir, 'Gemfile'), "source 'https://rubygems.org'\n")
    allow(RubyRaider::Schedules::Legacy).to receive(:new).and_wrap_original do |original, project, **options|
      original.call(project, adapter: adapter, **options)
    end
    expect(RubyRaider::Schedules::Notifier).not_to receive(:new) # rubocop:disable RSpec/ExpectInHook
  end

  after { FileUtils.rm_rf(dir) }

  def os_id(name) = RubyRaider::Schedules::Legacy::OldRule.os_id_for(dir, name)

  # [stdout, stderr, exit code or nil when it did not exit]
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

  it "removes the project's 4.1 schedules, its own last, and exits 2 with the notice on stderr" do
    result = raider('flow', 'run', 'tredssd', '--project', dir, '--trigger', 'schedule', '--retries', '1', '--notify', '--input', 'a=b')

    expect(result).to eq(['', "#{notice}\n", 2])
    expect(adapter.removed).to eq(%w[other tredssd])
  end

  it 'takes --project=VALUE, and f' do
    result = raider('f', 'run', 'tredssd', "--project=#{dir}", '--trigger', 'schedule')

    expect(result).to eq(['', "#{notice}\n", 2])
  end

  it 'takes the first --project only' do
    result = raider('flow', 'run', 'tredssd', '--project', dir, '--project', '/nonexistent')

    expect(result).to eq(['', "#{notice}\n", 2])
  end

  it 'still cleans up with invalid UTF-8 in another argument' do
    result = raider('flow', 'run', "a\xFF", '--project', dir, '--input', "x=\xFF")

    expect(result).to eq(['', "#{notice}\n", 2])
  end

  it 'says none was found for the project when there is nothing to remove' do
    adapter.ids.clear

    result = raider('flow', 'run', 'tredssd', '--project', dir, '--trigger', 'schedule')

    expect(result).to eq(['', "This schedule was made with Ruby Raider 4.1 and can't run in 4.2, and none was found for #{dir} " \
                              "to remove: see Upgrading from 4.1 in the README.\n", 2])
  end

  it 'exits 2 even when the cleanup misbehaves' do
    allow(RubyRaider::Schedules::Legacy).to receive(:new).and_raise(RuntimeError, 'odd')

    expect(raider('flow', 'run', 'tredssd', '--project', dir).last).to eq(2)
  end

  describe 'without a usable project' do
    let(:no_gemfile) { File.realpath(Dir.mktmpdir('legacy-stub-bare')) }

    after { FileUtils.rm_rf(no_gemfile) }

    it 'says the command was removed, exits 2 and cleans up nothing, whatever the argv' do
      gemfile_dir = File.realpath(Dir.mktmpdir('legacy-stub-gemfile-dir'))
      FileUtils.mkdir_p(File.join(gemfile_dir, 'Gemfile'))
      argvs = [%w[flow], %w[f], %w[flow --help], %w[flow help], %w[flow run tredssd --project], ['flow', 'run', 'tredssd', '--project', "#{dir}\xFF"],
               %w[flow run tredssd --project relative/dir], %w[flow run tredssd --project /nonexistent/raider],
               ['flow', 'run', 'tredssd', '--project', no_gemfile], ['flow', 'run', 'tredssd', '--project', gemfile_dir],
               ['flow', 'run', 'tredssd', '--project', "#{dir}\0"], %w[flow run tredssd --retries 1 --notify --input a=b]]

      results = argvs.map { |argv| raider(*argv) }

      expect(results).to all(eq(['', "#{removed_line}\n", 2]))
      expect(RubyRaider::Schedules::Legacy).not_to have_received(:new)
    ensure
      FileUtils.rm_rf(gemfile_dir)
    end

    it 'never takes the current folder' do
      result = Dir.chdir(dir) { raider('flow', 'run', 'tredssd', '--trigger', 'schedule') }

      expect(result).to eq(['', "#{removed_line}\n", 2])
      expect(adapter.removed).to be_empty
    end
  end

  it 'is not in raider help' do
    out, = raider('help')

    expect(out).not_to match(/\bflows?\b/)
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
