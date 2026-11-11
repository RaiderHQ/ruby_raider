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
        File.open(project.path('.gitignore'), File::RDWR | File::APPEND | File::CREAT | NOFOLLOW | NONBLOCK, 0o644, binmode: true) do |file|
          raise Error, '.gitignore must be a file' unless file.stat.file?

          content = file.read.to_s.b
          return false if content.each_line.any? { |line| line.chomp == GITIGNORE_LINE }

          prefix = content.empty? || content.end_with?("\n") ? '' : "\n"
          file.write("#{prefix}#{GITIGNORE_LINE}\n")
        end
        true
      rescue Errno::ELOOP, Errno::EMLINK
        raise Error, ".gitignore is a link: add #{GITIGNORE_LINE} to it yourself"
      rescue Errno::EISDIR
        raise Error, '.gitignore must be a file'
      end
    end
  end
end
