# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require 'yaml'
require_relative 'base'

module RubyRaider
  module Schedules
    # <kind dir>/schedules.yml: a project's schedules of one kind, sorted by name. The OS entries are made
    # from it; it is written whole through a temp file and a rename, so a reader never sees half a file.
    # A subclass passes the schedule class (a Rule with from_h, to_h and os_id_for); its Kind names the folder.
    # :reek:MissingSafeMethod { exclude: [ writable! ] } -- a check that raises, with no safe twin to offer
    class Store
      FILE = 'schedules.yml'
      NOFOLLOW = defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0
      NONBLOCK = defined?(File::NONBLOCK) ? File::NONBLOCK : 0

      # What delete returns for an entry it removed but could not read: enough to remove its OS entry
      class Removed
        attr_reader :name, :os_id

        def initialize(name, os_id)
          @name = name
          @os_id = os_id
          freeze
        end
      end

      def initialize(project, schedule_class)
        @project = project
        @schedule_class = schedule_class
        @dir = schedule_class.kind.dir
        @file = project.path("#{@dir}/#{FILE}")
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

      # Raises the Error save and delete would, before anything else is changed
      def writable!
        writable_entries
        nil
      end

      # Removes every entry with the name, readable or not. Returns the removed schedule, a Removed
      # (name and os_id) when the entry could not be read, or nil when there was none.
      def delete(name)
        entries = writable_entries
        named, kept = entries.partition { |entry| named?(entry, name) }
        return nil if named.empty?

        write(kept)
        named.filter_map { |entry| from_entry(entry) }.first || Removed.new(name, @schedule_class.os_id_for(@project.root, name))
      end

      private

      attr_reader :project

      def from_entry(entry)
        @schedule_class.from_h(entry, @project.root)
      rescue Error
        nil
      end

      def named?(entry, name) = entry.is_a?(Hash) && entry['name'] == name

      # The raw entries, nil when the file is not a schedules file or can't be read (missing reads as empty)
      def read_entries
        text = read_text
        return [] if text.nil?
        return nil unless text

        data = YAML.safe_load(text)
        return [] if data.nil?

        entries = data.is_a?(Hash) ? data['schedules'] : nil
        entries.is_a?(Array) ? entries : nil
      rescue Psych::Exception
        nil
      end

      # The entries to rewrite, keeping ones this version can't read; refuses to overwrite a broken file
      def writable_entries
        read_entries || raise(Error, "#{@dir}/#{FILE} is not a schedules file: fix or remove it, then try again")
      end

      # Read through one handle that is not a link; nil when there is no file, false when it is a link,
      # not a regular file or can't be read (so a write never replaces what it could not see)
      def read_text
        File.open(@file, File::RDONLY | NONBLOCK | NOFOLLOW) do |file|
          file.stat.file? ? file.read.to_s.force_encoding(Encoding::UTF_8) : false
        end
      rescue Errno::ENOENT
        nil
      rescue SystemCallError
        false
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
        dir = @project.path(@dir)
        FileUtils.mkdir_p(dir)
        raise Error, "#{@dir} must be a folder, not a link" unless File.lstat(dir).directory?

        File.chmod(0o700, dir)
        dir
      end
    end
  end
end
