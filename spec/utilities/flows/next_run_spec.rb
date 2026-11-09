# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/flows/next_run'

# Flow specs live under spec/utilities/flows, next to the code in lib/utilities/flows
RSpec.describe RubyRaider::Flows::NextRun do # rubocop:disable RSpec/FilePath
  let(:dir) { File.realpath(Dir.mktmpdir('flows-next-run')) }
  let(:project) { RubyRaider::Flows::Project.new(dir) }

  around do |example|
    zone = ENV.fetch('TZ', nil)
    ENV['TZ'] = 'Europe/Copenhagen'
    example.run
  ensure
    ENV['TZ'] = zone
  end

  after { FileUtils.rm_rf(dir) }

  def rule(every, at = '08:00', on: nil)
    RubyRaider::Flows::Schedule.build(project: project, name: 'report', every: every, at: at, on: on)
  end

  def next_after(schedule, *local)
    described_class.after(schedule, Time.local(*local))
  end

  # [wall clock, UTC offset in hours] of a local time
  def wall(time)
    [time.strftime('%F %R'), time.utc_offset / 3600]
  end

  describe 'every day' do
    it 'runs later today, or tomorrow once the time has passed' do
      expect([wall(next_after(rule('day'), 2026, 11, 9, 7, 59)), wall(next_after(rule('day'), 2026, 11, 9, 8, 0))]).to eq(
        [['2026-11-09 08:00', 1], ['2026-11-10 08:00', 1]]
      )
    end

    it 'is strictly after now, by seconds too' do
      expect(wall(next_after(rule('day'), 2026, 11, 9, 8, 0, 1))).to eq(['2026-11-10 08:00', 1])
    end

    it 'crosses a month and a year' do
      expect(wall(next_after(rule('day'), 2026, 12, 31, 9, 0))).to eq(['2027-01-01 08:00', 1])
    end
  end

  describe 'every weekday' do
    it 'skips the weekend' do
      # 2026-11-13 is a Friday
      expect(wall(next_after(rule('weekday'), 2026, 11, 13, 9, 0))).to eq(['2026-11-16 08:00', 1])
    end
  end

  describe 'every week' do
    it 'runs on its day, a week later once that has passed' do
      # 2026-11-09 is a Monday
      expect([wall(next_after(rule('week', on: 'wed'), 2026, 11, 9, 9, 0)), wall(next_after(rule('week', on: 'mon'), 2026, 11, 9, 8, 0))]).to eq(
        [['2026-11-11 08:00', 1], ['2026-11-16 08:00', 1]]
      )
    end
  end

  describe 'every hour' do
    it 'runs at the next matching minute' do
      expect([wall(next_after(rule('hour', ':15'), 2026, 11, 9, 10, 20)), wall(next_after(rule('hour', ':15'), 2026, 11, 9, 10, 14, 59))]).to eq(
        [['2026-11-09 11:15', 1], ['2026-11-09 10:15', 1]]
      )
    end

    it 'crosses midnight' do
      expect(wall(next_after(rule('hour', ':00'), 2026, 11, 9, 23, 30))).to eq(['2026-11-10 00:00', 1])
    end
  end

  # Copenhagen: 2026-03-29 02:00 CET jumps to 03:00 CEST; 2026-10-25 03:00 CEST falls back to 02:00 CET
  describe 'the last Sunday of March' do
    it 'runs a time in the skipped hour at the first minute after the gap' do
      expect(wall(next_after(rule('day', '02:30'), 2026, 3, 29, 0, 0))).to eq(['2026-03-29 03:00', 2])
    end

    it 'goes back to the normal time the next day' do
      expect(wall(next_after(rule('day', '02:30'), 2026, 3, 29, 3, 0))).to eq(['2026-03-30 02:30', 2])
    end

    it 'keeps a time outside the gap' do
      expect(wall(next_after(rule('day'), 2026, 3, 29, 0, 0))).to eq(['2026-03-29 08:00', 2])
    end

    it 'runs every hour at the next real matching minute' do
      expect(wall(next_after(rule('hour', ':30'), 2026, 3, 29, 1, 45))).to eq(['2026-03-29 03:30', 2])
    end
  end

  describe 'the last Sunday of October' do
    it 'runs a repeated time at its first occurrence' do
      expect(wall(next_after(rule('day', '02:30'), 2026, 10, 25, 0, 0))).to eq(['2026-10-25 02:30', 2])
    end

    it 'does not run again at the second occurrence' do
      first = next_after(rule('day', '02:30'), 2026, 10, 25, 0, 0)

      expect(wall(described_class.after(rule('day', '02:30'), first))).to eq(['2026-10-26 02:30', 1])
    end

    it 'runs every hour in both repeated hours' do
      first = next_after(rule('hour', ':30'), 2026, 10, 25, 1, 45)
      second = described_class.after(rule('hour', ':30'), first)

      expect([wall(first), wall(second), second - first]).to eq([['2026-10-25 02:30', 2], ['2026-10-25 02:30', 1], 3600.0])
    end

    it 'runs a week rule on the changeover day' do
      expect(wall(next_after(rule('week', '02:30', on: 'sun'), 2026, 10, 20, 12, 0))).to eq(['2026-10-25 02:30', 2])
    end
  end
end
