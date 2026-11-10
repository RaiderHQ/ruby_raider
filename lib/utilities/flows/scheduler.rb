# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'rbconfig'
require_relative '../schedules/next_run'
require_relative 'run_log'
require_relative 'schedule'
require_relative 'schedule_store'
require_relative '../schedules/adapter'
require_relative '../schedules/scheduler_steps'

module RubyRaider
  module Flows
    # `raider flow schedule | unschedule | schedules`: keeps the OS scheduler entries and
    # .raider/flows/schedules.yml in step. The OS entry is installed first and the yml written after,
    # so the yml never names an entry the OS scheduler refused.
    # :reek:TooManyInstanceVariables { max_instance_variables: 6 } -- the project, its store, the adapter and the injected streams and clock
    class Scheduler
      include Schedules::SchedulerSteps

      NOT_SET_UP = 'Flows are not set up in this project: run raider flow init'
      FLOW_NOT_FOUND = 'flow not found: unschedule'
      LAST = %w[status finished_at trigger failed_step results_dir].freeze
      TIME = '%a %-d %b %H:%M'

      # The OS scheduler for this machine, for flow schedules
      def self.adapter(runner: Schedules::Os::CommandRunner.new, host_os: RbConfig::CONFIG['host_os'])
        Schedules.adapter(kind: Schedule::KIND, runner: runner, host_os: host_os)
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
        @store.writable!
        old = @store.find(name)
        adapter.install(schedule)
        save(schedule)
        prefix = old ? "Replaced the schedule for #{name}" : "Scheduled #{name}"
        @out.puts("#{prefix}: #{rule(schedule)}. Next run #{Schedules::NextRun.after(schedule, now).strftime(TIME)}.")
      end

      def unschedule(name)
        raise Error, "Invalid flow name #{name.inspect}: use 1 to 60 of a-z, 0-9 and _ (not env)" unless Flows.valid_name?(name)

        # The OS entry first: when the scheduler refuses, the yml entry stays to retry with.
        # from_h is strict, so a stored entry's os_id is always this one.
        label = adapter.label
        was_there = adapter.remove(Schedule.os_id_for(@project.root, name))
        removed = delete(name, label)
        raise Error, "No schedule for #{name}" unless removed || was_there

        @out.puts(was_there ? "Unscheduled #{name}" : "Unscheduled #{name} (it was already gone from #{label})")
        return unless removed.is_a?(ScheduleStore::Removed)

        @err.puts(unreadable_warning(name, label))
      end

      def schedules(json: false)
        now = @now.call
        listed = @store.all
        rows = listed.map { |schedule| row(schedule, now) } + unlisted_rows(listed.map(&:name))
        return @out.puts(JSON.generate(rows.map { |entry| entry[:json] })) if json
        return @out.puts('No schedules yet: raider flow schedule <name> --every day --at 08:00') if rows.empty?

        rows.each { |entry| @out.puts(Flows.printable(entry[:text])) }
        note = missed_runs_note
        @out.puts(note) if note
      end

      private

      def adapter = @adapter ||= Scheduler.adapter

      attr_reader :store

      # .raider/flows/<name>/ for scheduler.log: 0700 folders that are not links, as flows/support/run.rb makes them
      def flow_dir(name)
        [ScheduleStore::DIR, "#{ScheduleStore::DIR}/#{name}"].each { |relative| private_dir(relative) }
      end

      def private_dir(relative)
        dir = @project.path(relative)
        FileUtils.mkdir_p(dir)
        raise Error, "#{relative} must be a folder, not a link" unless File.lstat(dir).directory?

        File.chmod(0o700, dir)
      rescue SystemCallError => e
        raise Error, "Could not make #{relative}: #{e.message}"
      end

      def row(schedule, now)
        name = schedule.name
        next_run = Schedules::NextRun.after(schedule, now)
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

      def os_state(schedule)
        return RUBY_NOT_FOUND unless ruby_found?(schedule)
        return FLOW_NOT_FOUND unless File.file?(@project.path("flows/#{schedule.name}_flow.rb"))

        os_entry_state(schedule.os_id)
      rescue Error => e
        "unknown (#{e.message})"
      end

      def rule(schedule) = schedule.notify ? "#{schedule.rule_text} (notify)" : schedule.rule_text

      def last_run(name)
        last = RunLog.new(@project, name).last_result
        last && LAST.to_h { |key| [key, last[key]] }
      end
    end
  end
end
