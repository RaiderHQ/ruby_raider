# frozen_string_literal: true

require 'json'
require 'rubocop'
require 'stringio'
require 'tmpdir'
require_relative 'content_helper'

RUBOCOP_WEB_AUTOMATIONS = %w[selenium watir].freeze

# Every generated project must pass the RuboCop it ships: its own .rubocop.yml, run in-process with
# this gem's bundle. The project is linted from a copy outside this repo, so RuboCop resolves the
# target Ruby the way a user's fresh project does (no TargetRubyVersion, so its 2.7 default) instead
# of picking up this repo's .ruby-version or gemspec. The end-to-end spec repeats the check with the
# project's own resolved gems.
describe 'Generated projects pass their own RuboCop' do
  def rubocop_report(project_name)
    Dir.mktmpdir('raider_rubocop') do |tmp|
      dir = File.join(tmp, File.basename(project_name))
      FileUtils.cp_r(project_name, dir)
      with_project_root(dir) { yield lint(dir), target_ruby(dir) }
    end
  end

  def with_project_root(dir)
    RuboCop::ConfigFinder.project_root = dir
    yield
  ensure
    RuboCop::ConfigFinder.project_root = nil
  end

  def target_ruby(dir)
    RuboCop::TargetRuby.new(RuboCop::ConfigLoader.configuration_from_file(File.join(dir, '.rubocop.yml'))).version
  end

  def lint(dir)
    report, exit_code = capture_rubocop_json(['--config', File.join(dir, '.rubocop.yml'), '--cache', 'false',
                                              '--format', 'json', dir])
    offenses = report.fetch('files').flat_map do |file|
      path = file.fetch('path').delete_prefix("#{dir}/")
      file.fetch('offenses').map do |offense|
        "#{path}:#{offense.dig('location', 'line')}: #{offense.fetch('cop_name')}: #{offense.fetch('message')}"
      end
    end
    { offenses: offenses, inspected: report.fetch('summary').fetch('inspected_file_count'), exit_code: exit_code }
  end

  def capture_rubocop_json(args)
    original = $stdout
    $stdout = StringIO.new
    exit_code = RuboCop::CLI.new.run(args)
    [JSON.parse($stdout.string), exit_code]
  ensure
    $stdout = original
  end

  def expect_no_offenses(project_name)
    expect(File).to exist(File.join(project_name, '.rubocop.yml'))
    rubocop_report(project_name) do |summary, target|
      offenses = summary.fetch(:offenses)
      expect(target).to eq(RuboCop::TargetRuby::DEFAULT_VERSION)
      expect(summary.fetch(:inspected)).to be_positive, "#{project_name}: RuboCop inspected no files"
      expect(offenses).to be_empty, "#{project_name} has #{offenses.size} RuboCop offenses:\n#{offenses.join("\n")}"
      expect(summary.fetch(:exit_code)).to eq(0)
    end
  end

  FRAMEWORKS.each do |framework|
    AUTOMATION_TYPES.each do |automation|
      { 'with examples' => true, 'without examples' => false }.each do |label, examples|
        it "has no offenses for #{framework} and #{automation} (#{label})" do
          expect_no_offenses(ensure_project(framework:, automation:, examples:))
        end
      end
    end

    RUBOCOP_WEB_AUTOMATIONS.each do |automation|
      it "has no offenses for #{framework} and #{automation} with accessibility" do
        name = "rubocop_axe_#{framework}_#{automation}"
        InvokeGenerators.generate_framework(automation:, framework:, name:, accessibility: true)
        expect_no_offenses(name)
      ensure
        FileUtils.rm_rf(name)
      end
    end
  end
end
