# frozen_string_literal: true

require 'rbconfig'
require_relative 'rule'
require_relative 'selection'
require_relative 'project'

module RubyRaider
  module Schedules
    # One scheduled test run: the shared rule (Rule) plus which tests run and how (show_browser). The OS
    # entry runs `raider schedule run NAME` only; the selection, retries, notify and show_browser are
    # read from schedules.yml at run time. Immutable.
    # :reek:TooManyInstanceVariables { max_instance_variables: 14 } -- the fields of a schedules.yml entry
    class Schedule < Rule
      KIND = Kind::TESTS
      KEYS = %w[name every at on retries notify show_browser selection os_id ruby bundle gem_env created_at].freeze
      LINUX = /linux/
      NO_BROWSER_ON_LINUX = "Show the browser isn't available for scheduled runs on Linux"

      attr_reader :show_browser, :selection

      def self.kind = KIND

      # Linux schedules run from systemd or cron, with no display: show_browser is refused there
      def self.build(project:, name:, every:, at: nil, on: nil, retries: 0, notify: false, show_browser: false, selection: Selection.all,
                     now: Time.now, host_os: RbConfig::CONFIG['host_os'])
        raise Error, NO_BROWSER_ON_LINUX if show_browser == true && host_os.match?(LINUX)

        root = project.root
        new(name: name, every: every, at: at, on: on, retries: retries, notify: notify, show_browser: show_browser, selection: selection,
            os_id: os_id_for(root, name), ruby: RbConfig.ruby, bundle: bundle_path, gem_env: captured_gem_env,
            project_root: root, created_at: now.getutc.iso8601)
      end

      # A schedules.yml entry; raises Error when it is not one this class wrote. A spec file that is gone
      # still loads (selection.missing_file names it).
      def self.from_h(hash, project_root, host_os: RbConfig::CONFIG['host_os'])
        raise Error, 'A schedule entry must be a mapping' unless hash.is_a?(Hash)

        fields = KEYS.to_h { |key| [key.to_sym, hash[key]] }
        fields[:selection] = Selection.from_h(hash['selection'], root: project_root, host_os: host_os)
        schedule = new(**fields, project_root: project_root)
        # Strict: an entry copied from another project, or a moved project, is not this project's entry
        raise Error, "Invalid os_id #{schedule.os_id.inspect} for #{schedule.name} in #{project_root}" unless schedule.os_id == os_id_for(project_root, schedule.name)

        schedule
      end

      def initialize(name:, every:, at:, on:, retries:, selection:, os_id:, ruby:, bundle:, gem_env:, project_root:, created_at:, notify: false,
                     show_browser: false)
        super()
        @name = checked_name(name)
        @every = checked_every(every)
        @at = checked_at(at)
        @on = checked_on(on)
        @retries = checked_retries(retries)
        @notify = checked_flag('notify', notify)
        @show_browser = checked_flag('show_browser', show_browser)
        @selection = checked_selection(selection)
        @os_id = checked_os_id(os_id)
        @ruby = checked_path('ruby', ruby)
        @bundle = checked_path('bundle', bundle)
        @gem_env = checked_gem_env(gem_env)
        @project_root = checked_path('project_root', project_root)
        @created_at = checked_text('created_at', created_at)
        freeze
      end

      def to_h
        { 'name' => name, 'every' => every, 'at' => at, 'on' => on, 'retries' => retries, 'notify' => notify, 'show_browser' => show_browser,
          'selection' => selection.to_h, 'os_id' => os_id, 'ruby' => ruby, 'bundle' => bundle, 'gem_env' => gem_env.dup, 'created_at' => created_at }
      end

      private

      def checked_name(name)
        return name.dup.freeze if name.is_a?(String) && KIND.valid_name?(name)

        raise Error, "Invalid schedule name #{Schedules.printable(name.inspect)}: use 1 to 60 of a-z, 0-9 and _"
      end

      def checked_selection(selection)
        return selection if selection.is_a?(Selection)

        raise Error, 'Invalid selection: use a Selection'
      end
    end
  end
end
