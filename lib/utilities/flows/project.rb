# frozen_string_literal: true

require 'erb'
require 'fileutils'

module RubyRaider
  module Flows
    NAME = /\A[a-z0-9_]{1,60}\z/
    # .raider/flows/env is the secrets file, so no flow may log to .raider/flows/env/
    RESERVED = %w[env].freeze

    def self.valid_name?(name) = NAME.match?(name.to_s) && !RESERVED.include?(name.to_s)

    # Text from a run log, safe to print: page text in a step title can't move the cursor or forge lines
    def self.printable(text) = text.to_s.gsub(/[[:cntrl:]]/, '?')

    # A problem that stops a flow command; exit_code follows `raider flow run` (2 = setup failed).
    class Error < StandardError
      attr_reader :exit_code

      def initialize(message, exit_code: 2)
        super(message)
        @exit_code = exit_code
      end
    end

    # A Ruby Raider project that holds flows in flows/<name>_flow.rb.
    class Project
      UNSUPPORTED = 'Flows need a Selenium web project made with Ruby Raider 4.0 or later'
      GITIGNORE_LINES = %w[flow-results/ .raider/flows/].freeze
      TEMPLATES = {
        'flows/flow_helper.rb' => 'flow_helper.tt',
        'flows/support/run.rb' => 'run.tt'
      }.freeze
      # gem 'ruby_raider', '~> 4.0' (any quotes); captures the major and minor
      PIN = /^(\s*gem\s+(["'])ruby_raider\2\s*,\s*(["']))~>\s*(\d+)\.(\d+)(?:\.\d+)?(\3)/
      FLOWS_PIN = [4, 1].freeze

      attr_reader :root

      def initialize(path)
        @root = File.realpath(path)
      rescue SystemCallError
        raise Error, "Project folder not found: #{path}"
      end

      def path(relative) = File.join(root, relative)

      # The flow file for a name, realpath-checked inside the project.
      def flow_file(name)
        raise Error, "Invalid flow name #{name.inspect}: use 1 to 60 of a-z, 0-9 and _ (not env)" unless Flows.valid_name?(name)

        file = path("flows/#{name}_flow.rb")
        raise Error, "No flow #{name}: flows/#{name}_flow.rb not found" unless File.file?(file)

        real = File.realpath(file)
        raise Error, "flows/#{name}_flow.rb points outside the project" unless real.start_with?("#{root}#{File::SEPARATOR}")

        real
      end

      def flow_names
        Dir.glob(path('flows/*_flow.rb')).map { |file| File.basename(file, '_flow.rb') }.select { |name| Flows.valid_name?(name) }.sort
      end

      def set_up? = TEMPLATES.keys.all? { |file| File.file?(path(file)) }

      # nil when flows can be added, otherwise why not
      def unsupported_reason
        gemfile = read('Gemfile')
        return UNSUPPORTED unless gemfile && selenium?(gemfile) && runtime?
        return UNSUPPORTED if old_pin?(gemfile)

        nil
      end

      # Returns the exit code: 0 done (or already done), 2 refused.
      def init(out: $stdout, err: $stderr)
        reason = unsupported_reason
        if reason
          err.puts(reason)
          return 2
        end

        created = write_templates
        updated = add_gitignore_lines
        pinned = pin_gem
        updated << 'Gemfile' if pinned
        report(out, created, updated, pinned)
        warn_unknown_pin(err)
        0
      end

      private

      def template_dir = File.expand_path('../../generators/templates/flows', __dir__)

      def read(relative)
        file = path(relative)
        File.file?(file) ? File.read(file) : nil
      end

      def selenium?(gemfile)
        gemfile.match?(/["']selenium-webdriver["']/) && !gemfile.match?(/["']appium_lib["']/)
      end

      # 4.0 projects load the runtime from the driver helper; 3.x ones used WaitHelper
      def runtime?
        read('helpers/driver_helper.rb').to_s.include?("require 'ruby_raider/runtime'")
      end

      def old_pin?(gemfile)
        match = gemfile.match(PIN)
        match ? match[4].to_i < FLOWS_PIN.first : false
      end

      def write_templates
        TEMPLATES.filter_map do |relative, template|
          file = path(relative)
          next if File.exist?(file)

          FileUtils.mkdir_p(File.dirname(file))
          File.write(file, ERB.new(File.read(File.join(template_dir, template)), trim_mode: '-').result)
          relative
        end
      end

      def add_gitignore_lines
        file = path('.gitignore')
        content = File.file?(file) ? File.read(file) : ''
        missing = GITIGNORE_LINES - content.lines.map(&:strip)
        return [] if missing.empty?

        prefix = content.empty? || content.end_with?("\n") ? '' : "\n"
        File.write(file, "#{content}#{prefix}#{missing.join("\n")}\n")
        ['.gitignore']
      end

      # Raises a ~> 4.0 pin to ~> 4.1 so `bundle exec raider flow` runs a gem that has flows.
      def pin_gem
        gemfile = read('Gemfile').to_s
        match = gemfile.match(PIN)
        return false unless match && ([match[4].to_i, match[5].to_i] <=> FLOWS_PIN).negative?

        File.write(path('Gemfile'), gemfile.sub(PIN) { "#{match[1]}~> #{FLOWS_PIN.join('.')}#{match[6]}" })
        true
      end

      # gem 'ruby_raider', '4.0.1' or path: ... isn't raised here, and an old gem has no `raider flow`
      def warn_unknown_pin(err)
        gemfile = read('Gemfile').to_s
        return if gemfile.match?(PIN) || !gemfile.match?(/^\s*gem\s+["']ruby_raider["']/)

        err.puts("Check that the ruby_raider line in your Gemfile allows #{FLOWS_PIN.join('.')} or later, then run bundle install")
      end

      def report(out, created, updated, pinned)
        if created.empty? && updated.empty?
          out.puts('Flows already set up')
          return
        end

        created.each { |file| out.puts("Created #{file}") }
        updated.each { |file| out.puts("Updated #{file}") }
        out.puts('Run bundle install') if pinned
        out.puts('Write a flow in flows/<name>_flow.rb, then run it with: raider flow run <name>')
      end
    end
  end
end
