# frozen_string_literal: true

require 'tmpdir'
require 'digest'
require_relative '../../../lib/utilities/flows/schedule'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::Schedule do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('flows-schedule')) }
  let(:project) { RubyRaider::Flows::Project.new(dir) }
  let(:now) { Time.utc(2026, 11, 9, 10, 0, 0) }

  def build(**options)
    described_class.build(project: project, name: 'report', every: 'day', at: '08:00', now: now, **options)
  end

  def error_for(**options)
    build(**options)
  rescue RubyRaider::Flows::Error => e
    e.message
  end

  after { FileUtils.rm_rf(dir) }

  describe 'rules' do
    it 'reads the hour and minute and spells the rule' do
      schedule = build(at: '18:05')

      expect([schedule.hour, schedule.minute, schedule.at, schedule.rule_text]).to eq([18, 5, '18:05', 'every day at 18:05'])
    end

    it 'takes :MM or HH:MM for every hour, ignores the hour and defaults to :00' do
      texts = [':15', '07:15', nil].map { |at| build(every: 'hour', at: at) }.map { |s| [s.at, s.rule_text] }

      expect(texts).to eq([['00:15', 'every hour at :15'], ['00:15', 'every hour at :15'], ['00:00', 'every hour at :00']])
    end

    it 'runs every day and every hour on all days, weekdays mon to fri, a week on its day' do
      days = [build, build(every: 'hour', at: ':00'), build(every: 'weekday'), build(every: 'week', on: 'wed')].map(&:days)

      expect(days).to eq([%w[mon tue wed thu fri sat sun], %w[mon tue wed thu fri sat sun], %w[mon tue wed thu fri], %w[wed]])
    end

    it 'spells weekday and week rules' do
      expect([build(every: 'weekday').rule_text, build(every: 'week', on: 'mon').rule_text]).to eq(['every weekday at 08:00', 'every week on mon at 08:00'])
    end

    it 'refuses an unknown every' do
      expect(error_for(every: 'month')).to include('use hour, day, weekday or week')
    end

    it 'refuses a missing or malformed at for day, weekday and week' do
      errors = [nil, '8:00', '24:00', '08:60', '08:00x', ':15'].map { |at| error_for(at: at) }

      expect(errors).to all(include('HH:MM'))
    end

    it 'refuses a malformed at for every hour' do
      expect([error_for(every: 'hour', at: ':60'), error_for(every: 'hour', at: '25:00')]).to all(include(':MM'))
    end

    it 'needs on for every week and refuses it otherwise' do
      expect([error_for(every: 'week'), error_for(every: 'week', on: 'monday'), error_for(on: 'mon')]).to eq(
        ['Every week needs on: use mon, tue, wed, thu, fri, sat or sun',
         'Invalid on "monday": use mon, tue, wed, thu, fri, sat or sun',
         'on is only for every week']
      )
    end

    it 'takes retries 0 to 3' do
      expect([build(retries: 3).retries, error_for(retries: 4), error_for(retries: '1')]).to eq([3, 'Invalid retries 4: use 0 to 3', 'Invalid retries "1": use 0 to 3'])
    end

    it 'refuses a bad flow name' do
      expect(error_for(name: '../x')).to include('Invalid flow name')
    end

    it 'refuses bad input names and values with control characters' do
      errors = [['Bad=1'], ['nokey'], ["note=a\nb"], ["note=a\tb"], ["note=a\0b"]].map { |inputs| error_for(inputs: inputs) }

      expect(errors).to all(start_with('Invalid input'))
    end

    it 'keeps hostile input values as plain argv items' do
      values = ["'; rm -rf ~; '", '</string>', '%h', '$(id)']
      schedule = build(inputs: values.map { |value| "note=#{value}" })

      expect(schedule.argv.last(4)).to eq(values.map { |value| "note=#{value}" })
    end
  end

  describe 'the OS entry' do
    it 'names the entry from the project realpath and the flow name' do
      digest = Digest::SHA256.hexdigest(dir)[0, 10]

      expect([build.os_id, described_class.os_id_for(dir, 'report')]).to eq(["dev.rubyraider.flow.#{digest}.report"] * 2)
    end

    it 'runs raider flow run under the absolute ruby and bundle' do
      expect(build.argv).to eq([RbConfig.ruby, Gem.bin_path('bundler', 'bundle'), 'exec', 'raider', 'flow', 'run', 'report',
                                '--project', dir, '--trigger', 'schedule'])
    end

    it 'adds retries only above 0 and --input with each pair' do
      expect(build(retries: 2, inputs: %w[a=1 b=2]).argv.last(5)).to eq(%w[--retries 2 --input a=1 b=2])
    end

    it 'runs in the project and logs to the flow folder' do
      expect([build.working_directory, build.log_path]).to eq([dir, File.join(dir, '.raider/flows/report/scheduler.log')])
    end

    it 'records when it was made' do
      expect(build.created_at).to eq('2026-11-09T10:00:00Z')
    end

    it 'is frozen' do
      schedule = build(inputs: %w[a=1])

      expect([schedule, schedule.inputs, schedule.gem_env]).to all(be_frozen)
    end
  end

  describe 'the env' do
    let(:bin) { File.dirname(RbConfig.ruby) }

    it 'captures GEM_HOME and GEM_PATH from the env Bundler started with' do
      allow(Bundler).to receive(:original_env).and_return('GEM_HOME' => '/gems/home', 'GEM_PATH' => '/gems/home:/gems/more', 'OTHER' => 'x')

      expect(build.env).to include('GEM_HOME' => '/gems/home', 'GEM_PATH' => '/gems/home:/gems/more', 'LANG' => 'en_US.UTF-8')
    end

    it 'leaves GEM_HOME and GEM_PATH out when they are not set' do
      allow(Bundler).to receive(:original_env).and_return('GEM_HOME' => '', 'PATH' => '/x')

      expect([build.gem_env, build.env.keys.sort]).to eq([{}, %w[LANG PATH]])
    end

    it 'reads ENV when Bundler is not loaded' do
      hide_const('Bundler')
      stub_const('ENV', { 'GEM_HOME' => '/env/home' })

      expect(build.gem_env).to eq('GEM_HOME' => '/env/home')
    end

    it 'puts the ruby and bundle folders on PATH before the system ones, once each' do
      folders = [bin, File.dirname(Gem.bin_path('bundler', 'bundle')), '/usr/bin', '/bin'].uniq

      expect(build.env['PATH']).to eq(folders.join(File::PATH_SEPARATOR))
    end
  end

  describe 'the yml shape' do
    let(:schedule) { build(every: 'week', on: 'fri', retries: 1, inputs: %w[a=1]) }

    it 'writes string keys' do
      expect(schedule.to_h.keys).to eq(%w[name every at on retries inputs os_id ruby bundle gem_env created_at])
    end

    it 'reads back what it wrote' do
      expect(described_class.from_h(schedule.to_h, dir).to_h).to eq(schedule.to_h)
    end

    it 'keeps the os_id it was scheduled under' do
      moved = described_class.from_h(schedule.to_h, '/elsewhere')

      expect([moved.os_id, moved.project_root]).to eq([schedule.os_id, '/elsewhere'])
    end

    it 'refuses entries that were tampered with' do
      bad = [{ 'every' => 'yearly' }, { 'os_id' => 'evil; id' }, { 'ruby' => 'ruby' }, { 'gem_env' => { 'RUBYOPT' => '-rx' } },
             { 'inputs' => ["a=\n"] }, { 'name' => nil }, { 'created_at' => 5 }]

      bad.each do |change|
        expect { described_class.from_h(schedule.to_h.merge(change), dir) }.to raise_error(RubyRaider::Flows::Error)
      end
    end

    it 'refuses a non-hash' do
      expect { described_class.from_h('x', dir) }.to raise_error(RubyRaider::Flows::Error)
    end
  end
end
