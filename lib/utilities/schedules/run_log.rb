# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'
require_relative 'base'
require_relative 'kind'

module RubyRaider
  module Schedules
    # <kind dir>/<name>/runs.jsonl: one JSON line per run, oldest first. `raider schedule run` appends to it
    # (status and counts only, never a message); flows/support/run.rb writes the flow ones.
    # :reek:TooManyConstants { max_constants: 7 } -- the read cap, the line cap, the files and the open flags
    class RunLog
      MAX_BYTES = 1024 * 1024
      MAX_LINES = 50
      FILE = 'runs.jsonl'
      # A busy run appends without the run lock: appends and the trim at MAX_LINES take this one. It is never
      # renamed (the trim renames a new runs.jsonl into place), so a lock on it keeps excluding.
      LOCK = 'runs.jsonl.lock'
      NOFOLLOW = defined?(File::NOFOLLOW) ? File::NOFOLLOW : 0
      NONBLOCK = defined?(File::NONBLOCK) ? File::NONBLOCK : 0

      # A 0700 folder <dir>/<name> inside the project; no part of it may be a link. Returns its path.
      def self.private_dir(project, *parts)
        path = project.root
        parts.flat_map { |part| part.split('/') }.each do |part|
          path = File.join(path, part)
          FileUtils.mkdir_p(path)
          raise Error, "#{path.delete_prefix("#{project.root}/")} must be a folder, not a link" unless File.lstat(path).directory?
        end
        File.chmod(0o700, path)
        path
      end

      def initialize(project, name, dir: Kind::TESTS.dir)
        @project = project
        @parts = [dir, name]
        @file = project.path("#{dir}/#{name}/#{FILE}")
        @lock = project.path("#{dir}/#{name}/#{LOCK}")
      end

      # Every readable line in the last MAX_BYTES, oldest first; a broken line is skipped
      def lines
        tail.lines.filter_map do |line|
          parsed = JSON.parse(line)
          parsed if parsed.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end
      end

      def last = lines.last

      # The last run that ran: a busy line only says another run held the lock
      def last_result = lines.reverse.find { |line| line['status'] != 'busy' }

      def find(run_id) = lines.reverse.find { |line| line['run_id'] == run_id }

      # Adds one line, keeping the last MAX_LINES. An append while there is room; otherwise the kept lines are
      # written to a temp file that replaces the log, so a reader never sees half of it. Never through a link.
      def append(line)
        RunLog.private_dir(@project, *@parts)
        locked do
          # A line cut short by a crash is ended first, so the new line stays whole
          raw = tail
          text = "#{JSON.generate(line)}\n"
          text = "\n#{text}" unless raw.empty? || raw.end_with?("\n")
          old = raw.lines
          old.size < MAX_LINES ? add(text) : replace(old.last(MAX_LINES - 1).join + text)
        end
      end

      private

      # Holds runs.jsonl.lock (a regular file, never through a link) while the block reads and writes the log
      def locked
        File.open(@lock, File::RDWR | File::CREAT | NOFOLLOW | NONBLOCK, 0o600) do |file|
          raise Error, "#{LOCK} must be a file" unless file.stat.file?

          file.flock(File::LOCK_EX)
          yield
        end
      rescue Errno::ELOOP, Errno::EMLINK
        raise Error, "#{LOCK} must be a file, not a link"
      end

      def add(text)
        File.open(@file, File::WRONLY | File::APPEND | File::CREAT | NOFOLLOW | NONBLOCK, 0o600) do |file|
          raise Error, "#{FILE} must be a file" unless file.stat.file?

          file.write(text)
        end
      rescue Errno::ELOOP, Errno::EMLINK
        raise Error, "#{FILE} must be a file, not a link"
      end

      def replace(text)
        temp = "#{@file}.#{SecureRandom.hex(6)}.tmp"
        File.open(temp, File::WRONLY | File::CREAT | File::EXCL | NOFOLLOW, 0o600) { |file| file.write(text) }
        File.rename(temp, @file)
      ensure
        FileUtils.rm_f(temp) if temp && File.exist?(temp)
      end

      # Read through one handle that is not a link, so the checks and the read see the same file
      def tail
        File.open(@file, File::RDONLY | NONBLOCK | NOFOLLOW) do |file|
          stat = file.stat
          return '' unless stat.file?

          skip = [stat.size - MAX_BYTES, 0].max
          file.seek(skip)
          text = file.read.to_s.force_encoding(Encoding::UTF_8)
          skip.positive? ? text.partition("\n").last : text
        end
      rescue SystemCallError
        ''
      end
    end
  end
end
