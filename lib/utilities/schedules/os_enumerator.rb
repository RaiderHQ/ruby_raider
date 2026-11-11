# frozen_string_literal: true

require_relative 'base'

module RubyRaider
  module Schedules
    # The schedules of one project and kind that the OS scheduler has, by enumerating it for the project's
    # os_id prefix ("<kind prefix>.<hash10>."). Every id is checked again here, so another project's, another
    # kind's or a malformed id never becomes a name. An OS scheduler that can't be read gives none.
    class OsEnumerator
      # schedule_class: a Rule subclass (its Kind and os_id_prefix_for); root: the project's real path
      def initialize(adapter, schedule_class:, root:)
        @adapter = adapter
        @kind = schedule_class.kind
        @prefix = schedule_class.os_id_prefix_for(root)
      end

      # The names, sorted and once each
      def names
        adapter = @adapter
        return [] unless adapter.respond_to?(:list_ids)

        prefix = @prefix
        Array(adapter.list_ids(prefix)).filter_map { |os_id| @kind.name_in(os_id) if @kind.listed?(os_id, prefix) }.uniq.sort
      rescue Error
        []
      end
    end
  end
end
