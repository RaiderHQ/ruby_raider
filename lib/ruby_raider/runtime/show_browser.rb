# frozen_string_literal: true

module Raider
  # Show the browser whatever the project's headless setting says. A scheduled or desktop run sets
  # RAIDER_SHOW_BROWSER=1; the project's driver_helper still adds --headless, and the filter prepended
  # here drops it. config.yml and driver_helper.rb are never written. Unset, nothing is prepended.
  module ShowBrowser
    ENV_KEY = 'RAIDER_SHOW_BROWSER'
    OPTIONS = %w[Chrome Edge Firefox].map { |browser| "Selenium::WebDriver::#{browser}::Options" }.freeze
    SWITCHES = %w[--headless -headless].freeze
    PREFIX = '--headless='
    ARGS_KEYS = [:args, 'args'].freeze

    module_function

    def headless?(arg) = arg.is_a?(String) && (SWITCHES.include?(arg) || arg.start_with?(PREFIX))

    def without_headless(args) = args.is_a?(Array) ? args.reject { |arg| headless?(arg) } : args

    # The Options classes the filter is on; empty unless the env value is exactly '1'
    def install(env = ENV)
      return [] unless env[ENV_KEY] == '1'

      OPTIONS.filter_map do |name|
        next unless Object.const_defined?(name)

        klass = Object.const_get(name)
        klass.prepend(Filter) unless klass.include?(Filter)
        klass
      end
    end

    # Drops the headless switches from args: given to new, from add_argument and from args=
    # :reek:ModuleInitialize -- prepended to the Options classes: its initialize wraps theirs
    module Filter
      def initialize(**opts)
        ARGS_KEYS.each { |key| opts[key] = ShowBrowser.without_headless(opts[key]) if opts.key?(key) }
        super
      end

      # The args, as Selenium's own add_argument returns them, also when the switch is dropped
      def add_argument(arg)
        return options[:args] if ShowBrowser.headless?(arg)

        super
      end

      def args=(value)
        super(ShowBrowser.without_headless(value))
      end
    end
  end
end
