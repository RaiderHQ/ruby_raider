# frozen_string_literal: true

require 'json'
require 'securerandom'
require_relative 'base'
require_relative 'kind'
require_relative 'run_log'

module RubyRaider
  module Schedules
    # Who is running the project's tests now, decided before rspec spawns (a busy run must never wipe
    # raider-results/):
    # - .raider/schedules/run.lock, held with flock among `raider schedule run`s; never removed;
    # - .raider/schedules/running.json {pid, name, run_id, started_at}, which the desktop is to write for its
    #   own runs too. A live pid there that is not ours means busy. It is read and written only as a regular file
    #   (O_NOFOLLOW), made with O_EXCL, and its pid is only checked, never signalled.
    class RunLock
      LOCK = 'run.lock'
      RUNNING = 'running.json'
      MAX_RUNNING_BYTES = 4096

      def initialize(project)
        @project = project
        @lock = nil
        @run_id = nil
      end

      # true with the lock held and running.json written; false when another run is going
      def acquire(name:, run_id:, started_at:)
        dir = RunLog.private_dir(@project, Kind::TESTS.dir)
        return false unless lock(File.join(dir, LOCK))

        running = File.join(dir, RUNNING)
        seen = inspect_running(running)
        return busy if seen && (seen[:changed] || live?(seen[:data]))
        return busy if seen && !remove_stale(running, seen[:id])

        write_running(running, name, run_id, started_at) || busy
      end

      # Removes running.json when it is still ours, then frees the lock
      def release
        running = @project.path("#{Kind::TESTS.dir}/#{RUNNING}")
        File.unlink(running) if @run_id && read_running(running)&.fetch('run_id', nil) == @run_id
      rescue SystemCallError
        nil
      ensure
        @run_id = nil
        @lock&.close
        @lock = nil
      end

      private

      def lock(path)
        file = File.open(path, File::RDWR | File::CREAT | RunLog::NOFOLLOW | RunLog::NONBLOCK, 0o600)
        @lock = file
        raise Error, "#{Kind::TESTS.dir}/#{LOCK} must be a file" unless file.stat.file?

        file.flock(File::LOCK_EX | File::LOCK_NB) ? true : busy
      rescue Errno::ELOOP, Errno::EMLINK
        raise Error, "#{Kind::TESTS.dir}/#{LOCK} must be a file, not a link"
      rescue Error
        busy
        raise
      end

      def busy
        @lock&.close
        @lock = nil
        false
      end

      # What is at running.json now: its identity (dev, ino, never through a link), its object when it is a regular
      # JSON file, and changed when it was replaced between the lstat and the read. nil when there is none.
      def inspect_running(running)
        stat = File.lstat(running)
        id = [stat.dev, stat.ino]
        data = nil
        changed = false
        if stat.file?
          File.open(running, File::RDONLY | RunLog::NOFOLLOW | RunLog::NONBLOCK) do |file|
            opened = file.stat
            changed = [opened.dev, opened.ino] != id
            data = parse_running(file) unless changed
          end
        end
        { id: id, data: data, changed: changed }
      rescue Errno::ENOENT
        nil
      rescue SystemCallError
        { id: nil, data: nil, changed: true }
      end

      # Moves the stale file aside and removes it only when it is still the one inspected. The desktop takes no
      # lock, so a running.json it wrote in between is put back (link never replaces a newer one) and counts as busy.
      def remove_stale(running, id)
        aside = "#{running}.#{SecureRandom.hex(6)}.stale"
        File.rename(running, aside)
        stat = File.lstat(aside)
        return File.unlink(aside).positive? if [stat.dev, stat.ino] == id

        restore(aside, running)
        false
      rescue Errno::ENOENT
        true
      end

      def restore(aside, running)
        File.link(aside, running)
      rescue SystemCallError
        nil
      ensure
        File.unlink(aside)
      end

      # Another process named by running.json is alive. kill(0) only checks: EPERM means alive but not ours to signal.
      def live?(data)
        pid = data&.fetch('pid', nil)
        return false unless pid.is_a?(Integer) && pid.positive? && pid != Process.pid

        Process.kill(0, pid)
        true
      rescue Errno::EPERM
        true
      rescue SystemCallError
        false
      end

      # Its JSON object, nil when it is missing, a link, not a regular file, too big or not an object
      def read_running(running)
        File.open(running, File::RDONLY | RunLog::NOFOLLOW | RunLog::NONBLOCK) { |file| parse_running(file) }
      rescue SystemCallError
        nil
      end

      # The object in an open running.json, nil when it is not a small regular file holding one
      def parse_running(file)
        stat = file.stat
        return nil unless stat.file? && stat.size <= MAX_RUNNING_BYTES

        data = JSON.parse(file.read.to_s)
        data.is_a?(Hash) ? data : nil
      rescue JSON::ParserError
        nil
      end

      # false when another writer made the file first
      def write_running(running, name, run_id, started_at)
        File.open(running, File::WRONLY | File::CREAT | File::EXCL | RunLog::NOFOLLOW, 0o600) do |file|
          file.write(JSON.generate('pid' => Process.pid, 'name' => name, 'run_id' => run_id, 'started_at' => started_at))
        end
        @run_id = run_id
        true
      rescue Errno::EEXIST
        false
      end
    end
  end
end
