# frozen_string_literal: true

require 'digest'
require 'rbconfig'
require 'time'
require_relative 'project'
require_relative 'runner'

module RubyRaider
  module Flows
    # One scheduled flow: the rule (every/at/on), how it runs (retries, inputs) and what the OS entry
    # runs (absolute ruby and bundle, GEM_HOME/GEM_PATH captured when it was scheduled). Immutable.
    # :reek:TooManyInstanceVariables { max_instance_variables: 12 } -- the fields of a schedules.yml entry
    # :reek:TooManyConstants { max_constants: 9 } -- the rule vocabulary, the OS entry parts and the yml keys
    class Schedule
      EVERY = %w[hour day weekday week].freeze
      DAYS = %w[mon tue wed thu fri sat sun].freeze
      DAYS_RULE = 'use mon, tue, wed, thu, fri, sat or sun'
      CLOCK = /\A([01]\d|2[0-3]):([0-5]\d)\z/
      MINUTE = /\A(?:[01]\d|2[0-3])?:([0-5]\d)\z/
      GEM_ENV = %w[GEM_HOME GEM_PATH].freeze
      SYSTEM_PATH = %w[/usr/bin /bin].freeze
      OS_ID_PREFIX = 'dev.rubyraider.flow'
      KEYS = %w[name every at on retries inputs os_id ruby bundle gem_env created_at].freeze

      attr_reader :name, :every, :at, :on, :retries, :inputs, :os_id, :ruby, :bundle, :gem_env, :project_root, :created_at

      def self.build(project:, name:, every:, at: nil, on: nil, retries: 0, inputs: [], now: Time.now)
        root = project.root
        new(name: name, every: every, at: at, on: on, retries: retries, inputs: inputs, os_id: os_id_for(root, name),
            ruby: RbConfig.ruby, bundle: Gem.bin_path('bundler', 'bundle'), gem_env: captured_gem_env,
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

      def self.os_id_for(project_root, name) = "#{OS_ID_PREFIX}.#{Digest::SHA256.hexdigest(project_root)[0, 10]}.#{name}"

      # The GEM_HOME and GEM_PATH raider started with (before bundle exec changed them), only when set
      def self.captured_gem_env
        env = defined?(Bundler) ? Bundler.original_env : ENV
        GEM_ENV.each_with_object({}) do |key, captured|
          value = env[key]
          captured[key] = value if value.is_a?(String) && !value.empty?
        end
      end

      def initialize(name:, every:, at:, on:, retries:, inputs:, os_id:, ruby:, bundle:, gem_env:, project_root:, created_at:)
        @name = checked_name(name)
        @every = checked_every(every)
        @at = checked_at(at)
        @on = checked_on(on)
        @retries = checked_retries(retries)
        @inputs = checked_inputs(inputs)
        @os_id = checked_os_id(os_id)
        @ruby = checked_path('ruby', ruby)
        @bundle = checked_path('bundle', bundle)
        @gem_env = checked_gem_env(gem_env)
        @project_root = project_root.to_s.dup.freeze
        @created_at = checked_text('created_at', created_at)
        freeze
      end

      def hour = at[0, 2].to_i

      def minute = at[3, 2].to_i

      def days
        case every
        when 'weekday' then DAYS.first(5)
        when 'week' then [on.to_s]
        else DAYS
        end
      end

      def argv
        command = [ruby, bundle, 'exec', 'raider', 'flow', 'run', name, '--project', project_root, '--trigger', 'schedule']
        command += ['--retries', retries.to_s] if retries.positive?
        command += ['--input', *inputs] unless inputs.empty?
        command
      end

      def env
        path = [File.dirname(ruby), File.dirname(bundle), *SYSTEM_PATH].uniq.join(File::PATH_SEPARATOR)
        { 'PATH' => path, 'LANG' => 'en_US.UTF-8' }.merge(gem_env)
      end

      def working_directory = project_root

      def log_path = File.join(project_root, '.raider', 'flows', name, 'scheduler.log')

      def rule_text
        case every
        when 'hour' then "every hour at #{at[2, 3]}"
        when 'week' then "every week on #{on} at #{at}"
        else "every #{every} at #{at}"
        end
      end

      def to_h
        { 'name' => name, 'every' => every, 'at' => at, 'on' => on, 'retries' => retries, 'inputs' => inputs.dup,
          'os_id' => os_id, 'ruby' => ruby, 'bundle' => bundle, 'gem_env' => gem_env.dup, 'created_at' => created_at }
      end

      private

      def checked_name(name)
        return name.dup.freeze if name.is_a?(String) && Flows.valid_name?(name)

        raise Error, "Invalid flow name #{name.inspect}: use 1 to 60 of a-z, 0-9 and _ (not env)"
      end

      def checked_every(every)
        return every.dup.freeze if EVERY.include?(every)

        raise Error, "Invalid every #{every.inspect}: use hour, day, weekday or week"
      end

      # HH:MM, or for every hour :MM or HH:MM (the hour ignored, :00 when left out), kept as HH:MM
      def checked_at(at)
        return clock(at) unless every == 'hour'
        return '00:00' if at.nil?

        match = MINUTE.match(at.to_s)
        raise Error, "Invalid at #{at.inspect}: use :MM or HH:MM for every hour" unless match

        "00:#{match[1]}"
      end

      def clock(at)
        raise Error, "Every #{every} needs at: use HH:MM (24h)" if at.nil?
        return at.dup.freeze if at.is_a?(String) && CLOCK.match?(at)

        raise Error, "Invalid at #{at.inspect}: use HH:MM (24h)"
      end

      def checked_on(on)
        unless every == 'week'
          raise Error, 'on is only for every week' unless on.nil?

          return nil
        end
        raise Error, "Every week needs on: #{DAYS_RULE}" if on.nil?
        return on.dup.freeze if DAYS.include?(on)

        raise Error, "Invalid on #{on.inspect}: #{DAYS_RULE}"
      end

      def checked_retries(retries)
        return retries if retries.is_a?(Integer) && retries.between?(0, 3)

        raise Error, "Invalid retries #{retries.inspect}: use 0 to 3"
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

      def checked_os_id(os_id)
        pattern = /\A#{Regexp.escape(OS_ID_PREFIX)}\.[0-9a-f]{10}\.#{Regexp.escape(name)}\z/
        return os_id.dup.freeze if os_id.is_a?(String) && pattern.match?(os_id)

        raise Error, "Invalid os_id #{os_id.inspect} for #{name}"
      end

      def checked_path(label, path)
        return checked_text(label, path) if path.is_a?(String) && File.absolute_path?(path)

        raise Error, "Invalid #{label} #{path.inspect}: use an absolute path"
      end

      def checked_gem_env(gem_env)
        raise Error, 'Invalid gem_env: use a mapping of GEM_HOME and GEM_PATH' unless gem_env.is_a?(Hash) && (gem_env.keys - GEM_ENV).empty?

        gem_env.to_h { |key, value| [key.dup.freeze, checked_text(key, value)] }.freeze
      end

      def checked_text(label, text)
        return text.dup.freeze if text.is_a?(String) && text.valid_encoding? && !text.empty? && !text.match?(/[[:cntrl:]]/)

        raise Error, "Invalid #{label} #{text.inspect}"
      end
    end
  end
end
