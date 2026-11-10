# frozen_string_literal: true

require 'securerandom'
require 'time'
require_relative 'base'
require_relative 'project'
require_relative 'schedule_store'
require_relative 'run_log'
require_relative 'run_lock'
require_relative 'run_report'
require_relative 'notifier'
require_relative 'spawn'

module RubyRaider
  module Schedules
    # `raider schedule run NAME`: what the OS entry runs, and what a person can run by hand. It owns the whole
    # run record (spec §4): it re-validates the entry, takes the lock before rspec spawns (busy never wipes
    # raider-results/), runs `bundle exec rspec` of the selection with retries and headless set through the
    # env, counts raider-results/run.json, appends the run line, copies the report, cleans up and notifies.
    # Exit 0 passed, 1 failed, 2 setup_error (or refused), 3 busy.
    # :reek:TooManyInstanceVariables { max_instance_variables: 7 } -- the project and the injected collaborators
    # :reek:TooManyConstants { max_constants: 6 } -- the exit codes, triggers, results folder, log cap and wording
    class RunWrapper
      EXIT_CODES = { 'passed' => 0, 'failed' => 1, 'setup_error' => 2, 'busy' => 3 }.freeze
      TRIGGERS = %w[manual schedule].freeze
      LOG_BYTES = 1024 * 1024
      MISSING = 'remove the schedule or add it again'
      ZERO = { 'total' => 0, 'passed' => 0, 'failed' => 0, 'skipped' => 0 }.freeze
      # Forward a wrapper INT only when it can't have come from a terminal Ctrl-C, which rspec gets too
      SPAWNER = ->(env, argv, chdir) { Spawn.call(env, argv, chdir, forward_int: !$stdin.tty?) }

      # spawner: (env, argv, chdir) -> [exit status or nil, stopped]; notifier: nil makes one only when needed
      def initialize(project, out: $stdout, err: $stderr, spawner: SPAWNER, clock: -> { Time.now }, notifier: nil)
        @project = project
        @out = out
        @err = err
        @spawner = spawner
        @clock = clock
        @notifier = notifier
        @lock = RunLock.new(project)
      end

      # The exit code. Raises Error (exit 2, no run line) for an unknown trigger or a schedule that is not in
      # schedules.yml or no longer valid there.
      def run(name, trigger: 'manual')
        raise Error, "Invalid trigger #{Schedules.printable(trigger.inspect)}: use #{TRIGGERS.join(' or ')}" unless TRIGGERS.include?(trigger)

        schedule = load(name)
        rotate_log(schedule) if trigger == 'schedule'
        record = { 'run_id' => SecureRandom.hex(8), 'started_at' => stamp, 'trigger' => trigger }
        outcome = attempt(schedule, record)
        finish(schedule, record, outcome)
      end

      private

      def load(name)
        schedule = ScheduleStore.new(@project).find(name) if Schedules.valid_name?(name)
        return schedule if schedule

        raise Error, "No test schedule #{Schedules.printable(name.inspect)} in #{ScheduleStore::DIR}/#{Store::FILE} (or it is not valid): " \
                     'see raider schedule list'
      end

      # {status, counts, report?, reason?, stopped?}; the lock is held from before the spawn to the run line
      def attempt(schedule, record)
        schedule.selection.check!(@project.root)
        return { status: 'busy' } unless @lock.acquire(name: schedule.name, run_id: record['run_id'], started_at: record['started_at'])

        outcome = spawn(schedule)
        outcome[:copied] = copy_report(schedule, outcome[:report])
        # A line that can't be written loses only the line: the stop, counts and exit code stay
        append_quietly(schedule, record, outcome)
        outcome.merge(recorded: true)
      rescue Error, SystemCallError => e
        { status: 'setup_error', reason: Schedules.printable(e.message) }
      ensure
        @lock.release
      end

      def spawn(schedule)
        since = @clock.call
        code, stopped = @spawner.call(env(schedule), argv(schedule), @project.root)
        report = RunReport.load(@project, since: since)
        { status: status(code, stopped, report&.counts), report: report, stopped: stopped }
      end

      # A stop wins over everything: an interrupted rspec exits 1 even when what it ran passed
      def status(code, stopped, counts)
        return 'setup_error' if stopped || counts.nil?
        return 'passed' if code&.zero? && counts['total'].positive?
        return 'failed' if code == 1 && counts['failed'].positive?

        'setup_error'
      end

      def argv(schedule)
        selection = schedule.selection
        paths = case selection.kind
                when 'tag' then ['--tag', selection.tag.to_s]
                when 'files' then selection.files
                else []
                end
        [schedule.ruby, schedule.bundle, 'exec', 'rspec', *paths]
      end

      # Spec §4a: the inherited values are dropped first (nil unsets), then retries and headless are set.
      # config/config.yml is never written.
      def env(schedule)
        show = schedule.show_browser
        { 'BUNDLE_GEMFILE' => @project.path('Gemfile'), 'RETRY_COUNT' => (schedule.retries + 1).to_s, 'RSPEC_RETRY_RETRY_COUNT' => nil,
          'HEADLESS' => show ? nil : 'true', 'RAIDER_SHOW_BROWSER' => show ? '1' : nil }
      end

      # The report's folder relative to the project, nil when there was no report of this run or it could not be copied
      def copy_report(schedule, report)
        return nil unless report

        relative = "#{Kind::TESTS.dir}/#{schedule.name}/last"
        RunLog.private_dir(@project, Kind::TESTS.dir, schedule.name)
        report.copy_to(@project.path(relative))
        relative
      rescue Error, SystemCallError => e
        @err.puts("Could not copy the report to #{relative}: #{Schedules.printable(e.message)}")
        nil
      end

      def append(schedule, record, outcome)
        line = { 'run_id' => record['run_id'], 'started_at' => record['started_at'], 'finished_at' => stamp, 'status' => outcome[:status],
                 'counts' => outcome[:report]&.counts || ZERO, 'trigger' => record['trigger'], 'results_dir' => RunReport::DIR }
        line['report_copy'] = outcome[:copied] if outcome[:copied]
        RunLog.new(@project, schedule.name).append(line)
      end

      # Busy and early setup errors get their line here, after the lock is gone; the rest have one already
      def finish(schedule, record, outcome)
        status = outcome[:status]
        append_quietly(schedule, record, outcome) unless outcome[:recorded]
        @out.puts("Schedule #{Schedules.printable(schedule.name)} #{result_text(schedule, record, outcome)}")
        notify(schedule, record, outcome) if schedule.notify && !outcome[:stopped] && %w[failed setup_error].include?(status)
        EXIT_CODES.fetch(status)
      end

      def append_quietly(schedule, record, outcome)
        append(schedule, record, outcome)
      rescue Error, SystemCallError => e
        @err.puts("Could not record the run: #{Schedules.printable(e.message)}")
      end

      def result_text(schedule, record, outcome)
        counts = outcome[:report]&.counts || ZERO
        return 'was stopped' if outcome[:stopped]

        case outcome[:status]
        when 'passed' then "passed: #{counts['total']} tests"
        when 'failed' then "failed: #{failures(counts)}"
        when 'busy' then 'is already running'
        else "could not start: #{start_reason(schedule, record, outcome, long: true)}"
        end
      end

      def failures(counts) = "#{counts['failed']} of #{counts['total']} tests failed"

      # The notifier never raises, so a notification can't change the exit code
      def notify(schedule, record, outcome)
        counts = outcome[:report]&.counts || ZERO
        body = outcome[:status] == 'failed' ? failures(counts) : "Could not start: #{start_reason(schedule, record, outcome, long: false)}"
        (@notifier ||= Notifier.new).notify("Ruby Raider: #{schedule.name} failed", body)
      end

      # A refusal names itself ("spec/x_spec.rb not found"); a run that started points at its output. Only a
      # scheduled run outside Windows has a scheduler.log: Windows tasks keep none.
      def start_reason(schedule, record, outcome, long:)
        reason = outcome[:reason]
        return long && reason.end_with?(' not found') ? "#{reason}: #{MISSING}" : reason if reason
        return "see #{Kind::TESTS.dir}/#{schedule.name}/scheduler.log" if record['trigger'] == 'schedule' && !Gem.win_platform?

        'see the run output'
      end

      # launchd and cron append to scheduler.log through a handle opened before this process started. Renaming
      # the file keeps that handle (POSIX), so the rest of this run's output lands in scheduler.log.1 and the
      # next run starts a new scheduler.log. A link or anything but a regular file is left alone.
      def rotate_log(schedule)
        log = @project.path("#{Kind::TESTS.dir}/#{schedule.name}/scheduler.log")
        stat = File.lstat(log)
        File.rename(log, "#{log}.1") if stat.file? && stat.size > LOG_BYTES
      rescue SystemCallError
        nil
      end

      def stamp = @clock.call.getutc.iso8601(3)
    end
  end
end
