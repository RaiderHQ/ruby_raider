# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'rbconfig'
require_relative '../../lib/commands/scaffolding_commands'

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

  describe 'commands' do
    it 'has no feature or steps command' do
      expect(ScaffoldingCommands.all_commands.keys).not_to include('feature', 'steps')
    end
  end

  describe 'scaffold in a directory that looks like a Cucumber project' do
    let(:raider_bin) { File.expand_path('../../bin/raider', __dir__) }

    it 'writes the spec and the page and nothing under features' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'Gemfile'), "gem 'cucumber'\n")
        FileUtils.mkdir_p(File.join(dir, 'features'))

        _out, err, status = Open3.capture3(RbConfig.ruby, raider_bin, 'g', 'scaffold', 'login', chdir: dir)

        expect(status.success?).to be(true), err
        expect(File).to exist(File.join(dir, 'spec/login_page_spec.rb'))
        expect(File).to exist(File.join(dir, 'page_objects/pages/login.rb'))
        expect(Dir.glob(File.join(dir, 'features/**/*')).select { |f| File.file?(f) }).to be_empty
      end
    end
  end
end
