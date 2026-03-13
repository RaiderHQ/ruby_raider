# frozen_string_literal: true

module RubyRaider
  # Displays the Ruby Raider logo as colored pixel art in the terminal.
  # Uses pre-rendered ANSI escape sequences with Unicode half-block characters
  # for true-color output. Falls back silently if the terminal doesn't support it.
  module Logo
    LOGO_PATH = File.expand_path('../assets/logo.ansi', __dir__)

    def self.display
      return unless File.exist?(LOGO_PATH)

      logo = File.read(LOGO_PATH)
      # Center each line based on terminal width
      width = terminal_width
      logo.each_line do |line|
        visible_length = line.gsub(/\e\[[0-9;]*m/, '').chomp.length
        padding = [(width - visible_length) / 2, 0].max
        puts "#{' ' * padding}#{line}"
      end
      puts
    end

    def self.terminal_width
      require 'io/console'
      IO.console&.winsize&.last || 80
    rescue LoadError
      80
    end

    private_class_method :terminal_width
  end
end
