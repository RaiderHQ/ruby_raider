# frozen_string_literal: true

require 'rbconfig'
require_relative 'base'
require_relative 'os/task_scheduler'

module RubyRaider
  module Schedules
    # Which tests a schedule runs: all of them, one tag, or listed spec files. Immutable.
    # Checking is in two steps: the shape and every path's syntax (new, from_h: a schedules.yml entry still
    # loads when a file was deleted), and whether each file is there (parse for add, check! for run). A file
    # that is there but resolves outside the project is refused by both.
    # :reek:MissingSafeMethod { exclude: [ check! ] } -- a check that raises; missing_file is its safe twin
    # :reek:TooManyConstants { max_constants: 7 } -- the kinds, the tag and file rules, the cap, Windows
    class Selection
      KINDS = %w[all tag files].freeze
      KEYS = %w[kind tag files].freeze
      TAG = /\A[A-Za-z0-9_:-]+\z/
      MAX_FILES = 200
      WINDOWS = /mswin|mingw|cygwin/
      FILE_RULE = 'use a path inside the project ending in _spec.rb, with no .. and no leading - or /'
      WINDOWS_RULE = 'Task Scheduler and ruby.exe would expand %...%, *, ?, [ or { in it on Windows: rename the file or use a tag'

      attr_reader :kind, :tag, :files

      def self.all = new(kind: 'all')

      # What `raider schedule add` was given: no files and no tag is all tests; every file must be there
      def self.parse(files:, tag:, root:, host_os: RbConfig::CONFIG['host_os'])
        raise Error, 'Invalid spec files: use a list of paths' unless files.is_a?(Array)
        raise Error, 'Use --tag or spec files, not both' if !tag.nil? && !files.empty?

        selection = if !tag.nil? then new(kind: 'tag', tag: tag)
                    elsif files.empty? then all
                    else new(kind: 'files', files: files, host_os: host_os)
                    end
        selection.check!(root)
      end

      # The selection of a schedules.yml entry; a missing file still loads (missing_file names it)
      def self.from_h(hash, root:, host_os: RbConfig::CONFIG['host_os'])
        raise Error, 'Invalid selection: use kind all, tag or files' unless hash.is_a?(Hash) && (hash.keys - KEYS).empty?

        selection = new(kind: hash['kind'], tag: hash['tag'], files: hash['files'], host_os: host_os)
        selection.missing_file(root)
        selection
      end

      def initialize(kind:, tag: nil, files: nil, host_os: RbConfig::CONFIG['host_os'])
        raise Error, "Invalid selection kind #{kind.inspect}: use all, tag or files" unless KINDS.include?(kind)

        @kind = kind.dup.freeze
        @tag = kind == 'tag' ? checked_tag(tag) : nothing('tag', tag)
        @files = kind == 'files' ? checked_files(files, host_os.match?(WINDOWS)) : nothing('files', files) || [].freeze
        freeze
      end

      # The first listed file that is not in the project (nil when all are there); raises when one resolves
      # outside the project. root is the project's real path.
      def missing_file(root) = files.reject { |file| present?(root, file) }.first

      # Itself when every file is there, otherwise raises
      def check!(root)
        missing = missing_file(root)
        raise Error, "#{missing} not found" if missing

        self
      end

      def to_h
        case kind
        when 'tag' then { 'kind' => kind, 'tag' => tag }
        when 'files' then { 'kind' => kind, 'files' => files.dup }
        else { 'kind' => kind }
        end
      end

      private

      def nothing(label, value)
        raise Error, "Invalid selection: #{label} is only for kind #{label == 'tag' ? 'tag' : 'files'}" unless value.nil?

        nil
      end

      def checked_tag(tag)
        return tag.dup.freeze if tag.is_a?(String) && TAG.match?(tag)

        raise Error, "Invalid tag #{Schedules.printable(tag.inspect)}: use letters, digits, _, : and -"
      end

      # Duplicates removed, order kept, then counted
      def checked_files(files, windows)
        raise Error, 'Invalid spec files: use a list of one or more paths' unless files.is_a?(Array) && !files.empty?

        unique = files.map { |file| checked_file(file, windows) }.uniq
        raise Error, "Too many spec files (#{unique.size}): select at most #{MAX_FILES}, or use a tag" if unique.size > MAX_FILES

        unique.freeze
      end

      def checked_file(file, windows)
        raise Error, "Invalid spec file #{Schedules.printable(file.inspect)}: #{FILE_RULE}" unless spec_path?(file, windows)
        raise Error, "Invalid spec file #{file.inspect}: #{WINDOWS_RULE}" if windows && file.match?(Regexp.union(Os::TaskScheduler::EXPANDS, Os::TaskScheduler::GLOB))

        file.dup.freeze
      end

      def spec_path?(file, windows)
        file.is_a?(String) && file.valid_encoding? && !file.match?(/[[:cntrl:]]/) && file.end_with?('_spec.rb') && relative?(file, windows)
      end

      def relative?(file, windows)
        return false if file.start_with?('-', '/') || File.absolute_path?(file)
        return false if windows && file.match?(/\A(?:\\|[A-Za-z]:)/)

        !file.split(windows ? %r{[/\\]} : '/').include?('..')
      end

      # true when the file is in the project, false when it is not there; raises when it resolves outside
      def present?(root, file)
        real = File.realpath(File.join(root, file))
        raise Error, "#{file} points outside the project" unless real.start_with?("#{root}#{File::SEPARATOR}")

        File.file?(real)
      rescue Errno::ENOENT, Errno::ENOTDIR
        false
      rescue SystemCallError => e
        raise Error, "#{file} can't be read: #{e.message}"
      end
    end
  end
end
