# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rbconfig'
require_relative 'next_run'
require_relative 'run_log'
require_relative 'schedule'
require_relative 'schedule_store'
require_relative 'os/command_runner'
require_relative 'os/launchd'
require_relative 'os/task_scheduler'
require_relative 'os/linux'

module RubyRaider
  module Flows
    # `raider flow schedule | unschedule | schedules`: keeps the OS scheduler entries and
    # .raider/flows/schedules.yml in step. The OS entry is installed first and the yml written after,
    # so the yml never names an entry the OS scheduler refused.
    # :reek:TooManyInstanceVariables { max_instance_variables: 6 } -- the project, its store, the adapter and the injected streams and clock
    class Scheduler
      NOT_SET_UP = 'Flows are not set up in this project: run raider flow init'
      RUBY_NOT_FOUND = 'Ruby not found: re-schedule'
      LAST = %w[status finished_at trigger failed_step results_dir].freeze
      TIME = '%a %-d %b %H:%M'

      # The OS scheduler for this machine; only Linux asks the system (is the user's systemd there?)
      def self.adapter(runner: Os::CommandRunner.new, host_os: RbConfig::CONFIG['host_os'])
        case host_os
        when /darwin/ then Os::Launchd.new(runner: runner)
        when /mswin|mingw|cygwin/ then Os::TaskScheduler.new(runner: runner)
        when /linux/ then Os::Linux.pick(runner)
        else raise Error, "Scheduling flows is not supported on #{host_os}"
        end
      end

      # adapter: nil picks the OS scheduler on first use, so a command refused earlier never touches it
      def initialize(project, adapter: nil, store: ScheduleStore.new(project), out: $stdout, err: $stderr, now: -> { Time.now })
        @project = project
        @adapter = adapter
        @store = store
        @out = out
        @err = err
        @now = now
      end

      def schedule(name, every:, at: nil, on: nil, retries: 0, inputs: [], notify: false)
        @project.flow_file(name)
        raise Error, NOT_SET_UP unless @project.set_up?

        now = @now.call
        schedule = Schedule.build(project: @project, name: name, every: every, at: at, on: on, retries: retries,
                                  inputs: inputs, notify: notify, now: now)
        flow_dir(name)
        old = @store.find(name)
        adapter.install(schedule)
        save(schedule)
        prefix = old ? "Replaced the schedule for #{name}" : "Scheduled #{name}"
        @out.puts("#{prefix}: #{rule(schedule)}. Next run #{NextRun.after(schedule, now).strftime(TIME)}.")
      end

      def unschedule(name)
        raise Error, "Invalid flow name #{name.inspect}: use 1 to 60 of a-z, 0-9 and _ (not env)" unless Flows.valid_name?(name)

        # The OS entry first: when the scheduler refuses, the yml entry stays to retry with.
        # from_h is strict, so a stored entry's os_id is always this one.
        label = adapter.label
        was_there = adapter.remove(Schedule.os_id_for(@project.root, name))
        removed = @store.delete(name)
        raise Error, "No schedule for #{name}" unless removed || was_there

        @out.puts(was_there ? "Unscheduled #{name}" : "Unscheduled #{name} (it was already gone from #{label})")
        return unless removed.is_a?(ScheduleStore::Removed)

        @err.puts("The schedules.yml entry for #{name} could not be read: a #{label} entry made from a different project path may remain")
      end

      def schedules(json: false)
        now = @now.call
        listed = @store.all
        rows = listed.map { |schedule| row(schedule, now) } + unlisted_rows(listed.map(&:name))
        return @out.puts(JSON.generate(rows.map { |entry| entry[:json] })) if json
        return @out.puts('No schedules yet: raider flow schedule <name> --every day --at 08:00') if rows.empty?

        rows.each { |entry| @out.puts(Flows.printable(entry[:text])) }
        note = adapter.respond_to?(:missed_runs_note) ? adapter.missed_runs_note : nil
        @out.puts(note) if note
      end

      private

      def adapter = @adapter ||= Scheduler.adapter

      # Writes the yml; when that fails the OS entry just installed is removed, so neither names the flow
      def save(schedule)
        @store.save(schedule)
      rescue Error, SystemCallError => e
        label = adapter.label
        begin
          adapter.remove(schedule.os_id)
        rescue Error => remove_error
          raise Error, "#{e.message} (and removing the #{label} entry failed: #{remove_error.message})"
        end
        raise Error, "#{e.message}: the #{label} entry was removed too, so #{schedule.name} is not scheduled"
      end

      # .raider/flows/<name>/ for scheduler.log: 0700 folders that are not links, as flows/support/run.rb makes them
      def flow_dir(name)
        [ScheduleStore::DIR, "#{ScheduleStore::DIR}/#{name}"].each do |relative|
          dir = @project.path(relative)
          FileUtils.mkdir_p(dir)
          raise Error, "#{relative} must be a folder, not a link" unless File.lstat(dir).directory?

          File.chmod(0o700, dir)
        end
      end

      def row(schedule, now)
        name = schedule.name
        next_run = NextRun.after(schedule, now)
        state = os_state(schedule)
        last = last_run(name)
        json = { 'name' => name, 'every' => schedule.every, 'at' => schedule.at, 'on' => schedule.on,
                 'retries' => schedule.retries, 'inputs' => schedule.inputs, 'notify' => schedule.notify, 'next_run_at' => next_run.iso8601,
                 'os_state' => state, 'last' => last }
        { json: json, text: line(name, rule(schedule), "next #{next_run.strftime(TIME)}", last, state) }
      end

      # Flows the OS scheduler still runs for this project although schedules.yml has no entry for them
      def unlisted_rows(listed)
        (@project.flow_names - listed).filter_map do |name|
          next unless present?(Schedule.os_id_for(@project.root, name))

          state = 'missing from schedules.yml'
          last = last_run(name)
          json = { 'name' => name, 'every' => nil, 'at' => nil, 'on' => nil, 'retries' => nil, 'inputs' => nil, 'notify' => nil,
                   'next_run_at' => nil, 'os_state' => state, 'last' => last }
          { json: json, text: line(name, '-', '-', last, state) }
        end
      end

      # A flow whose state can't be read is left out: only a listed schedule gets an unknown row
      def present?(os_id)
        adapter.present?(os_id)
      rescue Error
        false
      end

      # The OS entry runs `<ruby> <bundle> ...`: ruby is executed, bundle is only read by it
      def os_state(schedule)
        ruby = schedule.ruby
        bundle = schedule.bundle
        return RUBY_NOT_FOUND unless File.file?(ruby) && File.executable?(ruby) && File.file?(bundle) && File.readable?(bundle)

        adapter.present?(schedule.os_id) ? 'ok' : "missing from #{adapter.label}"
      rescue Error => e
        "unknown (#{e.message})"
      end

      def rule(schedule) = schedule.notify ? "#{schedule.rule_text} (notify)" : schedule.rule_text

      def last_run(name)
        last = RunLog.new(@project, name).last_result
        last && LAST.to_h { |key| [key, last[key]] }
      end

      def line(name, rule, next_run, last, state)
        result = last ? "#{last['status']}  #{last['finished_at']}" : 'never run'
        "#{name.ljust(30)}  #{rule}  #{next_run}  #{result}  #{state}"
      end
    end
  end
end
