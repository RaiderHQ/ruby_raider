# frozen_string_literal: true

require_relative 'store'
require_relative 'schedule'

module RubyRaider
  module Schedules
    # .raider/schedules/schedules.yml: the project's test schedules (Store with Schedule)
    class ScheduleStore < Store
      DIR = Schedule::KIND.dir
      GITIGNORE_LINE = "#{DIR}/".freeze

      def initialize(project)
        super(project, Schedule)
      end

      # Appends .raider/schedules/ to the project's .gitignore (made when missing) unless that exact line is
      # there; every byte already in the file is kept. The yml holds machine paths. true when it added it.
      # Read and written through one handle that is not a link, so a linked .gitignore is never written through.
      def ignore_in_git
        File.open(gitignore, File::RDWR | File::APPEND | File::CREAT | NOFOLLOW | NONBLOCK, 0o644, binmode: true) do |file|
          content = gitignore_text(file)
          return false if ignored?(content)

          prefix = content.empty? || content.end_with?("\n") ? '' : "\n"
          file.write("#{prefix}#{GITIGNORE_LINE}\n")
        end
        true
      rescue Errno::EACCES, Errno::EROFS
        # A .gitignore we may not write is fine when it already has the line
        return false if ignored?(File.open(gitignore, File::RDONLY | NOFOLLOW | NONBLOCK, binmode: true) { |file| gitignore_text(file) })

        raise
      rescue Errno::ELOOP, Errno::EMLINK
        raise Error, ".gitignore is a link: add #{GITIGNORE_LINE} to it yourself"
      rescue Errno::EISDIR
        raise Error, '.gitignore must be a file'
      end

      private

      def gitignore = project.path('.gitignore')

      def gitignore_text(file)
        raise Error, '.gitignore must be a file' unless file.stat.file?

        file.read.to_s.b
      end

      def ignored?(content) = content.each_line.any? { |line| line.chomp == GITIGNORE_LINE }
    end
  end
end
