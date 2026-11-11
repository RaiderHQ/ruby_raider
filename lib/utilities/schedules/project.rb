# frozen_string_literal: true

require_relative 'base'

module RubyRaider
  module Schedules
    # A project folder, by its real path: where its schedules and their files live
    # :reek:MissingSafeMethod { exclude: [ check_show_browser!, check_raider_version! ] } -- checks that raise; runtime_driver? and locked_raider_version are their safe twins
    # :reek:TooManyConstants { max_constants: 8 } -- the driver helper and Gemfile.lock checks
    class Project
      DRIVER_HELPER = 'helpers/driver_helper.rb'
      # This gem's version, read as Raider#current_version reads it
      OWN_VERSION = File.read(File.expand_path('../../version', __dir__)).strip.freeze
      # The ruby_raider spec line of a GEM, PATH or GIT section (LF or CRLF); never evaluated
      LOCKED_RAIDER = /^ {4}ruby_raider \(([0-9]+(?:\.[0-9A-Za-z]+)*)\)\r?$/
      MAX_LOCK_BYTES = 5_000_000
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

      # The OS entry runs `bundle exec raider schedule run`, so the project's own bundle must have this command
      def check_raider_version!(own = OWN_VERSION)
        needs = "Scheduling needs ruby_raider #{own} or later in this project"
        raise Error, "#{needs}: no Gemfile found" unless File.file?(path('Gemfile'))

        locked = locked_raider_version
        raise Error, "#{needs}: run bundle install first" if locked == :no_lock
        return if locked && Gem::Version.new(locked) >= Gem::Version.new(own)

        raise Error, "#{needs}: bundle update ruby_raider"
      end

      # The ruby_raider version Gemfile.lock resolves (any source), nil when it lists none, :no_lock without a lock
      def locked_raider_version
        lock = path('Gemfile.lock')
        return :no_lock unless File.file?(lock)

        File.binread(lock, MAX_LOCK_BYTES).to_s[LOCKED_RAIDER, 1]
      rescue SystemCallError
        :no_lock
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
