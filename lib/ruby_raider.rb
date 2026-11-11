# frozen_string_literal: true

require 'thor'

# Lazy-load top-level command classes to reduce CLI startup time.
autoload :ScaffoldingCommands, File.expand_path('commands/scaffolding_commands', __dir__)
autoload :UtilityCommands, File.expand_path('commands/utility_commands', __dir__)
autoload :ScheduleCommands, File.expand_path('commands/schedule_commands', __dir__)

module RubyRaider
  class Raider < Thor
    def self.exit_on_failure? = true

    # The commands whose arguments are checked for valid UTF-8 before Thor sees them
    GUARDED = %w[schedule sc].freeze

    # Thor runs a regex on every argument before any command, so invalid UTF-8 would crash it with a
    # backtrace; a schedule command says which argument instead and exits 2 like its other refusals

    def self.start(given_args = ARGV, config = {})
      bad = given_args.find { |arg| arg.is_a?(String) && !arg.valid_encoding? }
      if bad && GUARDED.include?(given_args.first)
        warn("Invalid argument #{bad.inspect}: use valid UTF-8")
        exit(2)
      end
      super
    end

    no_tasks do
      def current_version = File.read(File.expand_path('version', __dir__)).strip
    end

    desc 'new [PROJECT_NAME]', 'Creates a new framework based on settings picked'
    option :parameters,
           type: :hash, required: false, desc: 'Parameters to avoid using the menu', aliases: 'p'
    option :accessibility,
           type: :boolean, required: false, desc: 'Add axe accessibility testing'
    def new(project_name)
      require_relative 'utilities/logo'
      RubyRaider::Logo.display
      params = options[:parameters]
      if params
        params[:name] = project_name
        parsed_hash = params.transform_keys(&:to_sym)
        merge_flags(parsed_hash)
        return generate_from_parameters(parsed_hash)
      end

      MenuGenerator.new(project_name).generate_choice_menu
    end

    map 'n' => 'new'

    desc 'version', 'It shows the version of Ruby Raider you are currently using'

    def version
      puts "The version is #{current_version}, happy testing!"
    end

    map 'v' => 'version'

    desc 'generate', 'Provides access to all the scaffolding commands'
    subcommand 'generate', ScaffoldingCommands
    map 'g' => 'generate'

    desc 'utility', 'Provides access to all the utility commands'
    subcommand 'utility', UtilityCommands
    map 'u' => 'utility'

    desc 'schedule', 'Runs the tests on a schedule with the OS scheduler (add, list, remove, run)'
    subcommand 'schedule', ScheduleCommands
    map 'sc' => 'schedule'

    no_tasks do
      # -p values arrive as strings; examples must be true or false, in any case
      def generate_from_parameters(params)
        params[:examples] = parse_examples(params[:examples]) if params.key?(:examples)
        InvokeGenerators.generate_framework(params)
      end

      def parse_examples(value)
        normalised = value.to_s.downcase
        return normalised == 'true' if %w[true false].include?(normalised)

        raise Thor::Error, "Invalid examples #{value.to_s.inspect}. Allowed values: true, false"
      end

      def merge_flags(params)
        params[:accessibility] = true if options[:accessibility]
      end
    end
  end
end
