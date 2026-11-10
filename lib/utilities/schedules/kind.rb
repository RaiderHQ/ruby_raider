# frozen_string_literal: true

require_relative 'base'

module RubyRaider
  module Schedules
    # What kind of schedule an OS entry belongs to: the words that name it in each scheduler (os_id prefix,
    # cron tag, descriptions), the command it runs, where its files live and which names it takes.
    # Adapters get one, so an entry of one kind is never read or removed as another.
    # :reek:TooManyInstanceVariables { max_instance_variables: 8 } -- the words, folder and reserved names of one kind
    class Kind
      attr_reader :command, :os_id_prefix, :os_id_pattern, :dir, :noun, :plural, :remove_command, :reserved

      # command is the raider subcommand (`raider <command> run NAME`); it also names the os_id prefix and tags
      def initialize(command:, dir:, noun:, plural:, remove_command:, reserved: [])
        @command = command.dup.freeze
        @os_id_prefix = "dev.rubyraider.#{command}".freeze
        @os_id_pattern = /\A#{Regexp.escape(@os_id_prefix)}\.[0-9a-f]{10}\.([a-z0-9_]{1,60})\z/
        @dir = dir.dup.freeze
        @noun = noun.dup.freeze
        @plural = plural.dup.freeze
        @remove_command = remove_command.dup.freeze
        @reserved = reserved.map { |word| word.dup.freeze }.freeze
        freeze
      end

      def valid_name?(name) = Schedules.valid_name?(name) && !reserved.include?(name.to_s)

      # The name in an os_id of this kind, nil when it is not one
      def name_in(os_id)
        return nil unless os_id.is_a?(String)

        name = os_id_pattern.match(os_id)&.[](1)
        name if name && valid_name?(name)
      end

      def cron_tag = "# raider-#{command} "

      # The command line under a cron tag runs `raider <command> run <name> --project ... --trigger schedule`
      def our_command?(text, name) = text.include?(" exec raider #{command} run #{name} --project ") && text.include?(' --trigger schedule')

      def task_description(name, rule) = "Ruby Raider #{command} #{name} (#{rule})"

      def task_file_prefix = "raider-#{command}-task"

      def service_description(name) = "raider #{command} #{name}"

      def timer_description(name) = "raider #{command} #{name} schedule"

      def not_ours = "not a #{noun}"

      def stranded(name) = "This schedule is a systemd timer; run #{remove_command} #{name} from a session where systemctl --user works"

      def unsupported(host_os) = "Scheduling #{plural} is not supported on #{host_os}"

      # The schedules of `raider flow schedule` (4.1); removed with flows
      FLOW_LEGACY = new(command: 'flow', dir: '.raider/flows', noun: 'flow schedule', plural: 'flows',
                        remove_command: 'raider flow unschedule', reserved: %w[env])

      # The schedules of `raider schedule`: the project's tests, all, one tag or listed spec files
      TESTS = new(command: 'schedule', dir: '.raider/schedules', noun: 'test schedule', plural: 'tests',
                  remove_command: 'raider schedule remove')
    end
  end
end
