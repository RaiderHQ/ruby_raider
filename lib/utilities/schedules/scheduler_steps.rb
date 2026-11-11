# frozen_string_literal: true

require_relative 'base'

module RubyRaider
  module Schedules
    # The steps every scheduler shares (4.1 shared them too): the yml written after the OS entry with a
    # rollback, the yml entry removed after the OS one, and the parts of a list row that ask the OS.
    # The includer gives `adapter` and `store`.
    module SchedulerSteps
      RUBY_NOT_FOUND = 'Ruby not found: re-schedule'

      private

      # Writes the yml; when that fails the OS entry just installed is removed, so neither names the schedule
      def save(schedule)
        store.save(schedule)
      rescue Error, SystemCallError => e
        label = adapter.label
        begin
          adapter.remove(schedule.os_id)
        rescue Error => remove_error
          raise Error, "#{e.message} (and removing the #{label} entry failed: #{remove_error.message})"
        end
        raise Error, "#{e.message}: the #{label} entry was removed too, so #{schedule.name} is not scheduled"
      end

      # The OS entry is gone by now: say so when the yml can't be written
      def delete(name, label)
        store.delete(name)
      rescue Error, SystemCallError => e
        raise Error, "#{e.message}: the #{label} entry was already removed, but schedules.yml still lists #{name}"
      end

      def unreadable_warning(name, label)
        "The schedules.yml entry for #{name} could not be read: a #{label} entry made from a different project path may remain"
      end

      # The OS entry runs `<ruby> <bundle> ...`: ruby is executed, bundle is only read by it
      def ruby_found?(schedule)
        ruby = schedule.ruby
        bundle = schedule.bundle
        File.file?(ruby) && File.executable?(ruby) && File.file?(bundle) && File.readable?(bundle)
      end

      def os_entry_state(os_id) = adapter.present?(os_id) ? 'ok' : "missing from #{adapter.label}"

      # An entry whose state can't be read is left out: only a listed schedule gets an unknown row
      def present?(os_id)
        adapter.present?(os_id)
      rescue Error
        false
      end

      # nil also when there is no OS scheduler to ask (the rows already say unknown)
      def missed_runs_note
        current = adapter
        current.respond_to?(:missed_runs_note) ? current.missed_runs_note : nil
      rescue Error
        nil
      end

      def line(name, rule, next_run, last, state)
        result = last ? "#{last['status']}  #{last['finished_at']}" : 'never run'
        "#{name.ljust(30)}  #{rule}  #{next_run}  #{result}  #{state}"
      end
    end
  end
end
