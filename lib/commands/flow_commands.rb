# frozen_string_literal: true

require 'thor'
require_relative '../utilities/flows/project'

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

  def run_flow(name); end

  map 'run' => :run_flow

  desc 'list', 'Lists the flows with their last result'
  option :json, type: :boolean, desc: 'Print JSON for the desktop app'

  def list; end

  no_commands do
    def project
      RubyRaider::Flows::Project.new(options[:project] || Dir.pwd)
    end

    def stop(error)
      warn(error.message)
      exit(error.exit_code)
    end
  end
end
