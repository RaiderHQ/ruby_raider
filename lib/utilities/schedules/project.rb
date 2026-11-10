# frozen_string_literal: true

require_relative 'base'

module RubyRaider
  module Schedules
    # A project folder, by its real path: where its schedules and their files live
    class Project
      attr_reader :root

      def initialize(path)
        @root = File.realpath(path)
      rescue SystemCallError
        raise Error, "Project folder not found: #{path}"
      end

      def path(relative) = File.join(root, relative)
    end
  end
end
