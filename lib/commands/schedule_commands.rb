# frozen_string_literal: true

require 'thor'
require_relative '../utilities/schedules/legacy'
require_relative '../utilities/schedules/scheduler'
require_relative '../utilities/schedules/run_wrapper'

# raider schedule: runs the project's tests (all, one tag or listed spec files) with the OS scheduler.
# Spec files are positional, never an array option, so they mix with the options in any order.
# Every command first removes the project's 4.1 schedules (Legacy), which never changes its exit code or stdout.
class ScheduleCommands < Thor
  def self.exit_on_failure? = true

  class_option :project, type: :string, desc: 'The project folder (default: the current folder)'

  desc 'add NAME [SPEC_FILE ...]', 'Schedules the tests (all, --tag or the spec files), or replaces the schedule NAME'
  option :every, type: :string, desc: 'hour, day, weekday or week'
  option :at, type: :string, desc: 'HH:MM (24h, local time); for every hour :MM'
  option :on, type: :string, desc: 'mon to sun, for every week'
  option :tag, type: :string, desc: 'Run only the tests with this tag'
  option :show_browser, type: :boolean, desc: 'Show the browser, whatever the Headless setting'
  option :retries, type: :numeric, default: 0, desc: 'Re-run each failed test up to N times (0-3)'
  option :notify, type: :boolean, desc: 'Show a desktop notification when a scheduled run fails'

  def add(name, *files)
    scheduler.add(name, every: options[:every], files: files, tag: options[:tag], at: options[:at], on: options[:on],
                        retries: options[:retries], notify: options[:notify] || false,
                        show_browser: options[:show_browser] || false)
  rescue RubyRaider::Schedules::Error => e
    stop(e)
  end

  desc 'list', 'Lists the schedules with their next run and last result'
  option :json, type: :boolean, desc: 'Print JSON for the desktop app'

  def list
    current = scheduler
    current.list(json: options[:json] || false, notice: @notice)
  rescue RubyRaider::Schedules::Error => e
    stop(e)
  end

  desc 'remove NAME', 'Removes the schedule NAME from the OS scheduler and schedules.yml'

  def remove(name)
    scheduler.remove(name)
  rescue RubyRaider::Schedules::Error => e
    stop(e)
  end

  # `run` is a Thor reserved word, so the method has another name
  desc 'run NAME', 'Runs the schedule NAME now: exit 0 passed, 1 failed, 2 setup error, 3 busy'
  option :trigger, type: :string, default: 'manual', desc: 'manual or schedule (what the OS entry passes)'

  def run_schedule(name)
    exit(RubyRaider::Schedules::RunWrapper.new(cleaned_project).run(name, trigger: options[:trigger]))
  rescue RubyRaider::Schedules::Error => e
    stop(e)
  end

  map 'run' => :run_schedule

  no_commands do
    # The project, once its 4.1 schedules are cleaned up; the notice (on stderr already) is kept for list --json
    def cleaned_project
      project = RubyRaider::Schedules::Project.new(options[:project] || Dir.pwd)
      @notice = RubyRaider::Schedules::Legacy.new(project).cleanup
      project
    end

    def scheduler = RubyRaider::Schedules::Scheduler.new(cleaned_project)

    # One stderr line, whatever the message holds (a --project path can carry a newline)
    def stop(error)
      warn(RubyRaider::Schedules.printable(error.message))
      exit(error.exit_code)
    end
  end
end
