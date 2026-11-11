# frozen_string_literal: true

require 'rbconfig'
require_relative '../schedules/rule'
require_relative 'project'
require_relative 'runner'

module RubyRaider
  module Flows
    # One scheduled flow: the shared rule (Schedules::Rule) plus the flow's inputs. Immutable.
    # :reek:TooManyInstanceVariables { max_instance_variables: 13 } -- the fields of a schedules.yml entry
    class Schedule < Schedules::Rule
      DAYS = Schedules::DAYS
      KIND = Schedules::Kind::FLOW_LEGACY
      OS_ID_PREFIX = KIND.os_id_prefix
      KEYS = %w[name every at on retries inputs notify os_id ruby bundle gem_env created_at].freeze

      attr_reader :inputs

      def self.kind = KIND

      def self.build(project:, name:, every:, at: nil, on: nil, retries: 0, inputs: [], notify: false, now: Time.now)
        root = project.root
        new(name: name, every: every, at: at, on: on, retries: retries, inputs: inputs, notify: notify, os_id: os_id_for(root, name),
            ruby: RbConfig.ruby, bundle: bundle_path, gem_env: captured_gem_env,
            project_root: root, created_at: now.getutc.iso8601)
      end

      # A schedules.yml entry; raises Error when it is not one this class wrote
      def self.from_h(hash, project_root)
        raise Error, 'A schedule entry must be a mapping' unless hash.is_a?(Hash)

        fields = KEYS.to_h { |key| [key.to_sym, hash[key]] }
        schedule = new(**fields, project_root: project_root)
        # Strict: an entry copied from another project, or a moved project, is not this project's entry
        raise Error, "Invalid os_id #{schedule.os_id.inspect} for #{schedule.name} in #{project_root}" unless schedule.os_id == os_id_for(project_root, schedule.name)

        schedule
      end

      def initialize(name:, every:, at:, on:, retries:, inputs:, os_id:, ruby:, bundle:, gem_env:, project_root:, created_at:, notify: false)
        super()
        @name = checked_name(name)
        @every = checked_every(every)
        @at = checked_at(at)
        @on = checked_on(on)
        @retries = checked_retries(retries)
        @inputs = checked_inputs(inputs)
        @notify = checked_flag('notify', notify)
        @os_id = checked_os_id(os_id)
        @ruby = checked_path('ruby', ruby)
        @bundle = checked_path('bundle', bundle)
        @gem_env = checked_gem_env(gem_env)
        @project_root = checked_path('project_root', project_root)
        @created_at = checked_text('created_at', created_at)
        freeze
      end

      def argv
        command = super
        command += ['--retries', retries.to_s] if retries.positive?
        command << '--notify' if notify
        command += ['--input', *inputs] unless inputs.empty?
        command
      end

      def to_h
        { 'name' => name, 'every' => every, 'at' => at, 'on' => on, 'retries' => retries, 'inputs' => inputs.dup, 'notify' => notify,
          'os_id' => os_id, 'ruby' => ruby, 'bundle' => bundle, 'gem_env' => gem_env.dup, 'created_at' => created_at }
      end

      private

      def checked_name(name)
        return name.dup.freeze if name.is_a?(String) && Flows.valid_name?(name)

        raise Error, "Invalid flow name #{name.inspect}: use 1 to 60 of a-z, 0-9 and _ (not env)"
      end

      # name=value pairs as `raider flow run --input` takes them; a control character could break an OS entry
      def checked_inputs(inputs)
        raise Error, 'Invalid inputs: use a list of name=value' unless inputs.is_a?(Array)

        inputs.map do |pair|
          raise Error, "Invalid input #{pair.inspect}: use name=value in valid UTF-8" unless pair.is_a?(String) && pair.valid_encoding?

          key, value = pair.split('=', 2)
          raise Error, "Invalid input #{key.to_s.inspect}: #{Runner::INPUT_RULE}" unless value && Runner::INPUT.match?(key.to_s)
          raise Error, "Invalid input #{key.inspect}: the value contains a control character" if value.match?(/[[:cntrl:]]/)

          pair.dup.freeze
        end.freeze
      end
    end
  end
end
