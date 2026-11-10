# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/utilities/schedules/os_enumerator'
require_relative '../../../lib/utilities/schedules/schedule'
require_relative '../../../lib/utilities/flows/schedule'

RSpec.describe RubyRaider::Schedules::OsEnumerator do # rubocop:disable RSpec/FilePath
  # Answers list_ids with what it was given, recording the prefix asked for
  let(:fake_adapter) do
    Class.new do
      attr_reader :asked

      def initialize(ids = [], error: nil)
        @ids = ids
        @error = error
      end

      def list_ids(prefix)
        @asked = prefix
        raise @error if @error

        @ids
      end
    end
  end

  let(:root) { '/projects/shop' }
  let(:prefix) { RubyRaider::Schedules::Schedule.os_id_prefix_for(root) }
  let(:other) { RubyRaider::Schedules::Schedule.os_id_prefix_for('/projects/other') }
  let(:flow) { RubyRaider::Flows::Schedule.os_id_prefix_for(root) }

  def enumerator(adapter) = described_class.new(adapter, schedule_class: RubyRaider::Schedules::Schedule, root: root)

  it "asks for this project's prefix and returns the schedule names, sorted and once each" do
    adapter = fake_adapter.new(["#{prefix}smoke", "#{prefix}nightly", "#{prefix}smoke"])

    expect(enumerator(adapter).names).to eq(%w[nightly smoke])
    expect(adapter.asked).to eq(prefix)
  end

  it "ignores what an adapter should not have returned: another project's, a flow's and hostile ids" do
    hostile = ["#{other}nightly", "#{flow}nightly", "#{prefix}../../x", "#{prefix}a;rm -rf ~", "#{prefix}Bad", nil, 42,
               "#{prefix}ok\nx", "#{prefix}a\xFF".dup.force_encoding(Encoding::UTF_8), "#{prefix}#{'a' * 61}"]

    expect(enumerator(fake_adapter.new(hostile + ["#{prefix}ok"])).names).to eq(%w[ok])
  end

  it 'is empty when the OS scheduler can not be read, or the adapter can not enumerate' do
    failing = fake_adapter.new(error: RubyRaider::Schedules::Error.new('task list unreadable'))

    expect([enumerator(failing).names, enumerator(Object.new).names, enumerator(fake_adapter.new(nil)).names]).to eq([[], [], []])
  end

  it 'lets an unexpected error through' do
    expect { enumerator(fake_adapter.new(error: ArgumentError.new('bug'))).names }.to raise_error(ArgumentError, 'bug')
  end
end
