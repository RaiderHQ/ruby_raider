# frozen_string_literal: true

require 'json'
require_relative 'base'
require_relative 'kind'
require_relative 'run_log'

module RubyRaider
  module Schedules
    # Who is running the project's tests now, decided before rspec spawns (a busy run must never wipe
    # raider-results/):
    # - .raider/schedules/run.lock, held with flock among `raider schedule run`s; never removed;
    # - .raider/schedules/running.json {pid, name, run_id, started_at}, which the desktop writes for its own
    #   runs too. A live pid there that is not ours means busy. It is read and written only as a regular file
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
        return busy if live?(running)

        File.unlink(running) if File.symlink?(running) || File.exist?(running)
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
        raise Error, "#{Kind::TESTS.dir}/#{LOCK} must be a file" unless file.stat.file?

        @lock = file
        file.flock(File::LOCK_EX | File::LOCK_NB) ? true : busy
      rescue Errno::ELOOP, Errno::EMLINK
        raise Error, "#{Kind::TESTS.dir}/#{LOCK} must be a file, not a link"
      end

      def busy
        @lock&.close
        @lock = nil
        false
      end

      # Another process named by running.json is alive. kill(0) only checks: EPERM means alive but not ours to signal.
      def live?(running)
        pid = read_running(running)&.fetch('pid', nil)
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
        File.open(running, File::RDONLY | RunLog::NOFOLLOW | RunLog::NONBLOCK) do |file|
          stat = file.stat
          next nil unless stat.file? && stat.size <= MAX_RUNNING_BYTES

          data = JSON.parse(file.read.to_s)
          data.is_a?(Hash) ? data : nil
        end
      rescue SystemCallError, JSON::ParserError
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
