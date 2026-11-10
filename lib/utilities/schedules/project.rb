# frozen_string_literal: true

require_relative 'base'

module RubyRaider
  module Schedules
    # A project folder, by its real path: where its schedules and their files live
    # :reek:MissingSafeMethod { exclude: [ check_show_browser! ] } -- a check that raises; runtime_driver? is its safe twin
    class Project
      DRIVER_HELPER = 'helpers/driver_helper.rb'
      # Every 4.x Selenium driver_helper loads the runtime, which honours RAIDER_SHOW_BROWSER
      REQUIRES_RUNTIME = %r{^[ \t]*require[ \t]+(['"])ruby_raider/runtime\1}n
      MAX_HELPER_BYTES = 1_000_000
      NO_RUNTIME = 'Show the browser needs a project made with Ruby Raider 4.0 or later'

      attr_reader :root

      def initialize(path)
        @root = File.realpath(path)
      rescue SystemCallError
        raise Error, "Project folder not found: #{path}"
      end

      def path(relative) = File.join(root, relative)

      # `add --show-browser` refuses a project whose driver_helper can't drop --headless
      def check_show_browser!
        raise Error, NO_RUNTIME unless runtime_driver?
      end

      # true when helpers/driver_helper.rb is a regular file inside the project that requires the runtime
      def runtime_driver?
        real = File.realpath(path(DRIVER_HELPER))
        return false unless real.start_with?("#{root}#{File::SEPARATOR}") && File.file?(real)

        REQUIRES_RUNTIME.match?(File.binread(real, MAX_HELPER_BYTES).to_s)
      rescue SystemCallError
        false
      end
    end
  end
end
