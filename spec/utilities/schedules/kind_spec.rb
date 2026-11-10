# frozen_string_literal: true

require_relative '../../../lib/utilities/schedules/kind'

RSpec.describe RubyRaider::Schedules::Kind do # rubocop:disable RSpec/FilePath
  let(:kind) { described_class::FLOW_LEGACY }
  let(:os_id) { 'dev.rubyraider.flow.0123456789.report' }

  it 'keeps the 4.1 flow words' do
    expect([kind.os_id_prefix, kind.cron_tag, kind.dir, kind.task_file_prefix, kind.service_description('report'),
            kind.timer_description('report'), kind.task_description('report', 'every day at 08:00'), kind.not_ours,
            kind.unsupported('solaris')])
      .to eq(['dev.rubyraider.flow', '# raider-flow ', '.raider/flows', 'raider-flow-task', 'raider flow report',
              'raider flow report schedule', 'Ruby Raider flow report (every day at 08:00)', 'not a flow schedule',
              'Scheduling flows is not supported on solaris'])
  end

  it 'names the flow unschedule command for a stranded timer' do
    expect(kind.stranded('report'))
      .to eq('This schedule is a systemd timer; run raider flow unschedule report from a session where systemctl --user works')
  end

  it 'reads the name from an os_id of its own kind only' do
    expect([kind.name_in(os_id), kind.name_in('dev.rubyraider.schedule.0123456789.report'), kind.name_in("#{os_id}\n"),
            kind.name_in('dev.rubyraider.flow.0123456789.env'), kind.name_in(nil)]).to eq(['report', nil, nil, nil, nil])
  end

  it 'reserves env for flows while Schedules does not' do
    expect([kind.valid_name?('env'), RubyRaider::Schedules.valid_name?('env'), kind.valid_name?('a' * 61)]).to eq([false, true, false])
  end

  it 'knows its own command line under a cron tag' do
    line = '0 8 * * * cd /p && /usr/bin/env /r /b exec raider flow run report --project /p --trigger schedule >> /l 2>&1'
    expect([kind.our_command?(line, 'report'), kind.our_command?(line, 'other')]).to eq([true, false])
  end

  it 'is frozen' do
    expect([kind, kind.os_id_prefix, kind.reserved]).to all(be_frozen)
  end
end
