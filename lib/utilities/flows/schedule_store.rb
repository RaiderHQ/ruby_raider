# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require 'yaml'
require_relative 'schedule'

module RubyRaider
  module Flows
    # .raider/flows/schedules.yml: the project's scheduled flows, sorted by name. The OS entries are made
    # from it; it is written whole through a temp file and a rename, so a reader never sees half a file.
    class ScheduleStore
      DIR = '.raider/flows'
      FILE = 'schedules.yml'
      NOFOLLOW = defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0
      NONBLOCK = defined?(File::NONBLOCK) ? File::NONBLOCK : 0

      def initialize(project)
        @project = project
        @file = project.path("#{DIR}/#{FILE}")
      end

      # Every valid entry, sorted by name; a broken entry or file is skipped
      def all
        entries = read_entries
        return [] unless entries

        entries.filter_map { |entry| from_entry(entry) }.sort_by(&:name)
      end

      def find(name) = all.find { |schedule| schedule.name == name }

      # Adds the schedule, or replaces the one with its name
      def save(schedule)
        write(writable_entries.reject { |entry| named?(entry, schedule.name) } + [schedule.to_h])
        schedule
      end

      # The removed schedule, or nil when there was none
      def delete(name)
        removed = find(name)
        return nil unless removed

        write(writable_entries.reject { |entry| named?(entry, name) })
        removed
      end

      private

      def from_entry(entry)
        Schedule.from_h(entry, @project.root)
      rescue Error
        nil
      end

      def named?(entry, name) = entry.is_a?(Hash) && entry['name'] == name

      # The raw entries, nil when the file is not a schedules file (missing reads as empty)
      def read_entries
        text = read_text
        return [] if text.nil?

        data = YAML.safe_load(text)
        return [] if data.nil?

        entries = data.is_a?(Hash) ? data['schedules'] : nil
        entries.is_a?(Array) ? entries : nil
      rescue Psych::Exception
        nil
      end

      # The entries to rewrite, keeping ones this version can't read; refuses to overwrite a broken file
      def writable_entries
        read_entries || raise(Error, "#{DIR}/#{FILE} is not a schedules file: fix or remove it, then try again")
      end

      # Read through one handle that is not a link; nil when there is no file
      def read_text
        File.open(@file, File::RDONLY | NONBLOCK | NOFOLLOW) do |file|
          file.stat.file? ? file.read.to_s.force_encoding(Encoding::UTF_8) : ''
        end
      rescue Errno::ENOENT
        nil
      rescue SystemCallError
        ''
      end

      def write(entries)
        dir = private_dir
        sorted = entries.sort_by { |entry| entry.is_a?(Hash) ? entry['name'].to_s : '' }
        temp = File.join(dir, ".#{FILE}.#{SecureRandom.hex(6)}.tmp")
        File.open(temp, File::WRONLY | File::CREAT | File::EXCL | NOFOLLOW, 0o600) do |file|
          file.write(YAML.dump({ 'schedules' => sorted }))
          file.flush
          file.fsync
        end
        File.rename(temp, @file)
      ensure
        FileUtils.rm_f(temp) if temp && File.exist?(temp)
      end

      # A 0700 folder inside the project that is not a link, as flows/support/run.rb makes it
      def private_dir
        dir = @project.path(DIR)
        FileUtils.mkdir_p(dir)
        raise Error, "#{DIR} must be a folder, not a link" unless File.lstat(dir).directory?

        File.chmod(0o700, dir)
        dir
      end
    end
  end
end
