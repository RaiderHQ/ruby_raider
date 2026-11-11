# frozen_string_literal: true

require 'json'
require 'rbconfig'
require_relative 'adapter'
require_relative 'next_run'
require_relative 'os_enumerator'
require_relative 'project'
require_relative 'run_log'
require_relative 'schedule'
require_relative 'schedule_store'
require_relative 'scheduler_steps'
require_relative 'selection'

module RubyRaider
  module Schedules
    # `raider schedule add | remove | list`: keeps the OS scheduler entries and .raider/schedules/schedules.yml
    # in step (4.1's order). The OS entry is installed first and the yml written after, so the yml never names
    # an entry the OS scheduler refused; remove takes the OS entry first, so a refusal keeps the yml entry to
    # retry with. The OS entry is always built fresh (this ruby, bundle and gem env), never from the yml.
    # :reek:TooManyInstanceVariables { max_instance_variables: 7 } -- the project, its store, the adapter, the streams, clock and OS
    # :reek:TooManyConstants { max_constants: 7 } -- the kind, two time formats, the row keys and the list wording
    class Scheduler
      include SchedulerSteps

      KIND = Schedule::KIND
      TIME = '%a %H:%M'
      LIST_TIME = '%a %-d %b %H:%M'
      LAST = %w[status finished_at trigger counts].freeze
      EMPTY = 'No schedules yet: raider schedule add <name> --every day --at 08:00'
      UNLISTED = 'missing from schedules.yml'
      RULE_KEYS = %w[every at on retries notify show_browser selection next_run_at].freeze

      # The OS scheduler for this machine, for test schedules
      def self.adapter(runner: Os::CommandRunner.new, host_os: RbConfig::CONFIG['host_os'])
        Schedules.adapter(kind: KIND, runner: runner, host_os: host_os)
      end

      # adapter: nil picks the OS scheduler once add has checked everything else, so a refused command never touches it
      def initialize(project, adapter: nil, store: ScheduleStore.new(project), out: $stdout, err: $stderr, now: -> { Time.now },
                     host_os: RbConfig::CONFIG['host_os'])
        @project = project
        @adapter = adapter
        @store = store
        @out = out
        @err = err
        @now = now
        @host_os = host_os
      end

      # Adds the schedule, or replaces the one with its name. Every check runs before a folder, the yml or
      # the OS scheduler is touched.
      def add(name, every:, files: [], tag: nil, at: nil, on: nil, retries: 0, notify: false, show_browser: false)
        checked_name(name)
        now = @now.call
        selection = Selection.parse(files: files, tag: tag, root: @project.root, host_os: @host_os)
        schedule = Schedule.build(project: @project, name: name, every: every, at: at, on: on, retries: retries, notify: notify,
                                  show_browser: show_browser, selection: selection, now: now, host_os: @host_os)
        @project.check_show_browser! if schedule.show_browser
        current = adapter
        schedule_dirs(name)
        @store.writable!
        old = @store.find(name)
        current.install(schedule)
        save(schedule)
        ignore_in_git
        @out.puts("#{old ? 'Replaced' : 'Scheduled'} #{name}: #{schedule.rule_text}, next run #{NextRun.after(schedule, now).strftime(TIME)}")
      end

      def remove(name)
        checked_name(name)
        label = adapter.label
        was_there = adapter.remove(Schedule.os_id_for(@project.root, name))
        removed = delete(name, label)
        raise Error, "No schedule #{name}" unless removed || was_there

        @out.puts(was_there ? "Removed #{name}" : "Removed #{name} (it was already gone from #{label})")
        @err.puts(unreadable_warning(name, label)) if removed.is_a?(Store::Removed)
      end

      # notice: a one-time line for the top of the list (PR B's cleanup); nil until then
      def list(json: false, notice: nil)
        now = @now.call
        listed = @store.all
        rows = listed.map { |schedule| row(schedule, now) } + unlisted_rows(listed.map(&:name))
        return @out.puts(JSON.generate({ 'notice' => notice, 'schedules' => rows.map { |entry| entry[:json] } })) if json

        @out.puts(Schedules.printable(notice)) if notice
        return @out.puts(EMPTY) if rows.empty?

        rows.each { |entry| @out.puts(Schedules.printable(entry[:text])) }
        note = missed_runs_note
        @out.puts(note) if note
      end

      private

      attr_reader :store

      def adapter = @adapter ||= Scheduler.adapter(host_os: @host_os)

      def checked_name(name)
        return if name.is_a?(String) && KIND.valid_name?(name)

        raise Error, "Invalid schedule name #{Schedules.printable(name.inspect)}: use 1 to 60 of a-z, 0-9 and _"
      end

      # .raider/schedules/ and .raider/schedules/<name>/ (scheduler.log): 0700, no part of either a link
      def schedule_dirs(name)
        RunLog.private_dir(@project, KIND.dir)
        RunLog.private_dir(@project, KIND.dir, name)
      rescue SystemCallError => e
        raise Error, "Could not make #{KIND.dir}/#{name}: #{e.message}"
      end

      # The schedule is installed and saved by now, so a .gitignore that can't take the line only warns
      def ignore_in_git
        @store.ignore_in_git
      rescue Error, SystemCallError => e
        @err.puts("Could not add #{ScheduleStore::GITIGNORE_LINE} to .gitignore: #{Schedules.printable(e.message)}")
      end

      def row(schedule, now)
        name = schedule.name
        next_run = NextRun.after(schedule, now)
        state = os_state(schedule)
        last = last_run(name)
        json = { 'name' => name, 'every' => schedule.every, 'at' => schedule.at, 'on' => schedule.on, 'retries' => schedule.retries,
                 'notify' => schedule.notify, 'show_browser' => schedule.show_browser, 'selection' => schedule.selection.to_h,
                 'next_run_at' => next_run.iso8601, 'os_state' => state, 'last' => last }
        { json: json, text: line(name, rule(schedule), "next #{next_run.strftime(LIST_TIME)}", last, state) }
      end

      # This project's OS entries that schedules.yml has no entry for, found by enumerating the OS scheduler
      def unlisted_rows(listed)
        (unlisted_names - listed).map do |name|
          last = last_run(name)
          json = { 'name' => name, **RULE_KEYS.to_h { |key| [key, nil] }, 'os_state' => UNLISTED, 'last' => last }
          { json: json, text: line(name, '-', '-', last, UNLISTED) }
        end
      end

      def unlisted_names
        OsEnumerator.new(adapter, schedule_class: Schedule, root: @project.root).names
      rescue Error
        []
      end

      # The ruby first, then the spec files (no need to ask the OS about a schedule that can't run), then the OS
      def os_state(schedule)
        return RUBY_NOT_FOUND unless ruby_found?(schedule)

        missing = schedule.selection.missing_file(@project.root)
        return "test file not found: #{missing}" if missing

        os_entry_state(schedule.os_id)
      rescue Error => e
        "unknown (#{Schedules.printable(e.message)})"
      end

      def rule(schedule)
        selection = schedule.selection
        which = case selection.kind
                when 'tag' then "tag #{selection.tag}"
                when 'files' then selection.files.size == 1 ? selection.files.first : "#{selection.files.size} files"
                else 'all tests'
                end
        flags = [('notify' if schedule.notify), ('browser shown' if schedule.show_browser)].compact
        "#{which}, #{schedule.rule_text}#{" (#{flags.join(', ')})" unless flags.empty?}"
      end

      def last_run(name)
        last = RunLog.new(@project, name, dir: KIND.dir).last_result
        last && LAST.to_h { |key| [key, last[key]] }
      end
    end
  end
end
