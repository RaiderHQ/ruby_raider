# frozen_string_literal: true

require 'open3'

RSpec.describe 'ScaffoldingCommands' do
  describe 'dependencies' do
    it 'loads without relying on transitive requires for Pathname' do
      # Loads the file in a clean Ruby process where nothing else has required 'pathname'.
      # This catches the exact bug where Pathname is used but never explicitly required,
      # which works in test suites (rspec loads pathname transitively) but crashes at runtime.
      script = <<~RUBY
        require_relative '../../lib/commands/scaffolding_commands'
        puts 'OK'
      RUBY

      stdout, stderr, status = Open3.capture3('ruby', '-e', script, chdir: __dir__)
      expect(status.success?).to be(true),
                                 "ScaffoldingCommands failed to load in isolation:\n#{stderr}"
      expect(stdout.strip).to eq('OK')
    end
  end
end
