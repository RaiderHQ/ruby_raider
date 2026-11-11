# frozen_string_literal: true

require_relative 'legacy'
require_relative 'project'

module RubyRaider
  module Schedules
    # What a Ruby Raider 4.1 OS entry reaches now: `raider flow run NAME --project ROOT --trigger schedule ...`.
    # Raider.start sends it here before Thor, so any argv works. It removes the project's 4.1 schedules (its
    # own entry last), writes one line to stderr (the entry's scheduler.log) and always exits 2. It never
    # sends a notification and never takes the project from the current folder.
    module LegacyStub
      EXIT = 2
      REMOVED = 'This command was removed in Ruby Raider 4.2. To run tests on a schedule, use raider schedule add.'
      OPTION = '--project'

      # The exit code: always 2
      def self.run(argv, err: $stderr)
        root = project_root(argv)
        root ? clean(root, own_name(argv), err) : err.puts(REMOVED)
        EXIT
      rescue StandardError
        EXIT
      end

      def self.clean(root, name, err)
        return if Legacy.new(Project.new(root), err: err).cleanup(last: name)

        err.puts(Schedules.printable("This schedule was made with Ruby Raider 4.1 and can't run in 4.2, and none was found for #{root} " \
                                     'to remove: see Upgrading from 4.1 in the README.'))
      end

      # The real path of the first --project value: valid UTF-8, absolute, a folder with a regular Gemfile
      def self.project_root(argv)
        path = project_value(argv)
        return nil unless path.is_a?(String) && path.valid_encoding? && !path.include?("\0") && File.absolute_path?(path)

        root = File.realpath(path)
        File.directory?(root) && File.lstat(File.join(root, 'Gemfile')).file? ? root : nil
      rescue SystemCallError
        nil
      end

      # --project VALUE or --project=VALUE, whichever comes first
      def self.project_value(argv)
        argv.each_with_index do |arg, index|
          next unless arg.is_a?(String) && arg.valid_encoding?
          return argv[index + 1] if arg == OPTION
          return arg.delete_prefix("#{OPTION}=") if arg.start_with?("#{OPTION}=")
        end
        nil
      end

      # The name after the first run, when it is a valid 4.1 name
      def self.own_name(argv)
        index = argv.index('run')
        name = index && argv[index + 1]
        name if name.is_a?(String) && name.valid_encoding? && Legacy::KIND.valid_name?(name)
      end
    end
  end
end
