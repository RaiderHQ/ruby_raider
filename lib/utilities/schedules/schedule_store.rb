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
      def ignore_in_git
        file = project.path('.gitignore')
        raise Error, '.gitignore must be a file' if File.exist?(file) && !File.file?(file)

        content = File.file?(file) ? File.binread(file) : ''.b
        return false if content.each_line.any? { |line| line.chomp == GITIGNORE_LINE }

        prefix = content.empty? || content.end_with?("\n") ? '' : "\n"
        File.open(file, 'ab') { |io| io.write("#{prefix}#{GITIGNORE_LINE}\n") }
        true
      end
    end
  end
end
