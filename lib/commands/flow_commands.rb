# frozen_string_literal: true

require 'thor'
require 'json'
require_relative '../utilities/flows/runner'
require_relative '../utilities/flows/scheduler'

# raider flow: recordings without assertions that run on their own.
class FlowCommands < Thor
  def self.exit_on_failure? = true

  class_option :project, type: :string, desc: 'The project folder (default: the current folder)'

  desc 'init', 'Adds flows/flow_helper.rb and the .gitignore lines to a Selenium web project'

  def init
    code = project.init
    exit(code) unless code.zero?
  rescue RubyRaider::Flows::Error => e
    stop(e)
  end

  # `run` is a Thor reserved word, so the method has another name
  desc 'run NAME', 'Runs flows/NAME_flow.rb headless with its own results folder and run log'
  option :headed, type: :boolean, desc: 'Show the browser'
  option :retries, type: :numeric, default: 0, desc: 'Re-run the whole flow up to N times (0-3), 30 s apart'
  option :input, type: :array, desc: 'Flow inputs as name=value (read with flow_input)'
  option :trigger, type: :string, default: 'manual', desc: 'manual, schedule or desktop'
  option :notify, type: :boolean, desc: 'Show a desktop notification when the flow fails'

  def run_flow(name)
    runner = RubyRaider::Flows::Runner.new(project)
    exit(runner.run(name, headed: options[:headed], retries: options[:retries], inputs: options[:input],
                          trigger: options[:trigger], notify: options[:notify] || false))
  rescue RubyRaider::Flows::Error => e
    stop(e)
  end

  map 'run' => :run_flow

  desc 'list', 'Lists the flows with their last result'
  option :json, type: :boolean, desc: 'Print JSON for the desktop app'

  def list
    summaries = RubyRaider::Flows::RunLog.summaries(project)
    return puts(JSON.generate(summaries)) if options[:json]
    return puts('No flows yet: write one in flows/<name>_flow.rb') if summaries.empty?

    summaries.each { |flow| puts(list_line(flow)) }
  rescue RubyRaider::Flows::Error => e
    stop(e)
  end

  desc 'schedule NAME', 'Runs a flow on a schedule with the OS scheduler'
  option :every, type: :string, desc: 'hour, day, weekday or week'
  option :at, type: :string, desc: 'HH:MM (24h, local time); for every hour :MM'
  option :on, type: :string, desc: 'mon to sun, for every week'
  option :retries, type: :numeric, default: 0, desc: 'Re-run the whole flow up to N times (0-3)'
  option :input, type: :array, desc: 'Flow inputs as name=value'
  option :notify, type: :boolean, desc: 'Show a desktop notification when a scheduled run fails'

  def schedule(name)
    scheduler.schedule(name, every: options[:every], at: options[:at], on: options[:on], retries: options[:retries],
                             inputs: options[:input] || [], notify: options[:notify] || false)
  rescue RubyRaider::Flows::Error => e
    stop(e)
  end

  desc 'unschedule NAME', 'Removes the schedule of a flow'

  def unschedule(name)
    scheduler.unschedule(name)
  rescue RubyRaider::Flows::Error => e
    stop(e)
  end

  desc 'schedules', 'Lists the scheduled flows with their next run and last result'
  option :json, type: :boolean, desc: 'Print JSON for the desktop app'

  def schedules
    scheduler.schedules(json: options[:json] || false)
  rescue RubyRaider::Flows::Error => e
    stop(e)
  end

  no_commands do
    def project
      RubyRaider::Flows::Project.new(options[:project] || Dir.pwd)
    end

    def scheduler = RubyRaider::Flows::Scheduler.new(project)

    def list_line(flow)
      last = flow['last']
      result = last ? RubyRaider::Flows.printable("#{last['status']}  #{last['finished_at']}") : 'never run'
      "#{flow['name'].ljust(30)}  #{result}"
    end

    def stop(error)
      warn(error.message)
      exit(error.exit_code)
    end
  end
end
