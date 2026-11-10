# frozen_string_literal: true

require 'digest'
require 'time'
require_relative 'kind'

module RubyRaider
  module Schedules
    # What every schedule shares, flow or tests: the rule (every/at/on), retries and notify, and what the OS
    # entry runs (absolute ruby and bundle, GEM_HOME/GEM_PATH captured when it was scheduled). A subclass
    # names its Kind (self.kind), checks its own name and fields in its initialize, and freezes.
    # :reek:TooManyConstants { max_constants: 7 } -- the rule vocabulary and the OS entry parts
    class Rule
      EVERY = %w[hour day weekday week].freeze
      DAYS = Schedules::DAYS
      DAYS_RULE = 'use mon, tue, wed, thu, fri, sat or sun'
      CLOCK = /\A([01]\d|2[0-3]):([0-5]\d)\z/
      MINUTE = /\A(?:[01]\d|2[0-3])?:([0-5]\d)\z/
      GEM_ENV = %w[GEM_HOME GEM_PATH].freeze
      SYSTEM_PATH = %w[/usr/bin /bin].freeze

      attr_reader :name, :every, :at, :on, :retries, :notify, :os_id, :ruby, :bundle, :gem_env, :project_root, :created_at

      # The Kind of the subclass's schedules
      def self.kind = raise(NotImplementedError, "#{self} must name its Kind")

      def self.os_id_for(project_root, name) = "#{os_id_prefix_for(project_root)}#{name}"

      # What every os_id of this kind for the project starts with: "<kind prefix>.<hash10>."
      def self.os_id_prefix_for(project_root) = "#{kind.os_id_prefix}.#{Digest::SHA256.hexdigest(project_root)[0, 10]}."

      def self.bundle_path
        Gem.bin_path('bundler', 'bundle')
      rescue Gem::GemNotFoundException, Gem::MissingSpecError => e
        raise Error, "Bundler not found for this Ruby (#{e.message}): gem install bundler, then try again"
      end

      # The GEM_HOME and GEM_PATH raider started with (before bundle exec changed them), only when set
      def self.captured_gem_env
        env = defined?(Bundler) ? Bundler.original_env : ENV
        GEM_ENV.each_with_object({}) do |key, captured|
          value = env[key]
          captured[key] = value if value.is_a?(String) && !value.empty?
        end
      end

      def kind = self.class.kind

      def hour = at[0, 2].to_i

      def minute = at[3, 2].to_i

      def days
        case every
        when 'weekday' then DAYS.first(5)
        when 'week' then [on.to_s]
        else DAYS
        end
      end

      # `raider <command> run NAME`, as the OS entry runs it
      def argv = [ruby, bundle, 'exec', 'raider', kind.command, 'run', name, '--project', project_root, '--trigger', 'schedule']

      def env
        path = [File.dirname(ruby), File.dirname(bundle), *SYSTEM_PATH].uniq.join(File::PATH_SEPARATOR)
        { 'PATH' => path, 'LANG' => 'en_US.UTF-8' }.merge(gem_env)
      end

      def working_directory = project_root

      def log_path = File.join(project_root, kind.dir, name, 'scheduler.log')

      def rule_text
        case every
        when 'hour' then "every hour at #{at[2, 3]}"
        when 'week' then "every week on #{on} at #{at}"
        else "every #{every} at #{at}"
        end
      end

      private

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

      # An entry written before the flag existed has no key: off
      def checked_flag(label, flag)
        return flag == true if [true, false, nil].include?(flag)

        raise Error, "Invalid #{label} #{flag.inspect}: use true or false"
      end

      def checked_os_id(os_id)
        pattern = /\A#{Regexp.escape(kind.os_id_prefix)}\.[0-9a-f]{10}\.#{Regexp.escape(name)}\z/
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
