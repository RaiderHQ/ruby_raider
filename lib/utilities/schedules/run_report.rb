# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'
require 'time'
require_relative 'base'
require_relative 'run_log'

module RubyRaider
  module Schedules
    # raider-results/run.json of the run that just ended, as raider_reporter wrote it when rspec finished.
    # A run that died before that leaves the previous run's file, so it counts only when its run started at
    # (or up to SLACK before) the spawn; without a start time, when the file is not older than the spawn.
    # raider-results/ is only read, never changed, and nothing in it is read through a link.
    # :reek:TooManyConstants { max_constants: 7 } -- the folder, its files, the caps and the slack
    class RunReport
      DIR = 'raider-results'
      RUN = 'run.json'
      INDEX = 'index.html'
      ATTACHMENTS = 'attachments'
      SLACK = 2
      MAX_RUN_BYTES = 256 * 1024 * 1024
      MAX_ATTACHMENT_BYTES = 50 * 1024 * 1024

      attr_reader :counts

      # The report of the run spawned at since, nil when there is none
      def self.load(project, since:)
        dir = project.path(DIR)
        return nil unless File.lstat(dir).directory?

        bytes, mtime = read_file(File.join(dir, RUN), MAX_RUN_BYTES)
        data = bytes && JSON.parse(bytes)
        return nil unless data.is_a?(Hash) && data['results'].is_a?(Array) && fresh?(data['run'], mtime, since)

        new(dir, bytes, data['results'])
      rescue SystemCallError, JSON::ParserError
        nil
      end

      # [content, mtime] of a regular file opened without following a link, nil when it is not one or too big
      def self.read_file(path, max)
        File.open(path, File::RDONLY | RunLog::NOFOLLOW | RunLog::NONBLOCK) do |file|
          stat = file.stat
          stat.file? && stat.size <= max ? [file.read.to_s, stat.mtime] : nil
        end
      rescue SystemCallError
        nil
      end

      def self.fresh?(run, mtime, since)
        started = run.is_a?(Hash) ? run['started_at'] : nil
        return mtime >= since unless started.is_a?(String)

        Time.iso8601(started) >= since - SLACK
      rescue ArgumentError
        false
      end

      def initialize(dir, run_json, results)
        @dir = dir
        @run_json = run_json
        statuses = results.map { |result| result.is_a?(Hash) ? result['status'] : nil }
        @counts = { 'total' => statuses.size, 'passed' => statuses.count('passed'),
                    'failed' => statuses.count { |status| %w[failed quarantined].include?(status) },
                    'skipped' => statuses.count { |status| %w[pending skipped].include?(status) } }.freeze
      end

      # Copies run.json, index.html and (when they come to at most MAX_ATTACHMENT_BYTES) the attachments to
      # target, replacing what was there: built in a temp folder beside it, then renamed into place.
      def copy_to(target)
        temp = "#{target}.#{SecureRandom.hex(6)}.tmp"
        Dir.mkdir(temp, 0o700)
        File.binwrite(File.join(temp, RUN), @run_json)
        index = RunReport.read_file(File.join(@dir, INDEX), MAX_RUN_BYTES)
        File.binwrite(File.join(temp, INDEX), index.first) if index
        copy_attachments(temp)
        swap(temp, target)
        true
      ensure
        FileUtils.rm_rf(temp) if temp && File.exist?(temp)
      end

      private

      def copy_attachments(temp)
        files = regular_files(File.join(@dir, ATTACHMENTS))
        return unless files && files.sum { |_, size| size } <= MAX_ATTACHMENT_BYTES

        FileUtils.mkdir_p(File.join(temp, ATTACHMENTS))
        files.each_key { |relative| copy_file(File.join(@dir, ATTACHMENTS, relative), File.join(temp, ATTACHMENTS, relative)) }
      end

      # Streams one file that is still a regular file when opened (not a link); anything else is skipped
      def copy_file(source, target)
        File.open(source, File::RDONLY | RunLog::NOFOLLOW | RunLog::NONBLOCK) do |from|
          next unless from.stat.file?

          FileUtils.mkdir_p(File.dirname(target))
          File.open(target, File::WRONLY | File::CREAT | File::EXCL | RunLog::NOFOLLOW, 0o600) { |to| IO.copy_stream(from, to, MAX_ATTACHMENT_BYTES) }
        end
      rescue Errno::ELOOP, Errno::EMLINK, Errno::ENOENT
        nil
      end

      # {relative path => size} of the regular files under dir (links and anything else skipped); nil once
      # they pass the cap or when dir is not a folder
      def regular_files(dir, prefix = nil, found = {})
        return nil unless File.lstat(dir).directory?

        Dir.children(dir).sort.each do |child|
          relative = prefix ? File.join(prefix, child) : child
          stat = File.lstat(File.join(dir, child))
          if stat.directory? then return nil unless regular_files(File.join(dir, child), relative, found)
          elsif stat.file? then found[relative] = stat.size
          end
          return nil if found.sum { |_, size| size } > MAX_ATTACHMENT_BYTES
        end
        found
      rescue SystemCallError
        nil
      end

      # The old copy moves aside first, so target is never half old and half new
      def swap(temp, target)
        old = "#{target}.#{SecureRandom.hex(6)}.old"
        File.rename(target, old) if File.symlink?(target) || File.exist?(target)
        File.rename(temp, target)
      ensure
        FileUtils.rm_rf(old) if old && (File.symlink?(old) || File.exist?(old))
      end
    end
  end
end
