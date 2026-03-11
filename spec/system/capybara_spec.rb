# frozen_string_literal: true

require_relative '../../lib/ruby_raider'
require 'open3'

FRAMEWORKS = %w[cucumber rspec minitest].freeze unless defined?(FRAMEWORKS)

describe 'Capybara based frameworks' do
  before(:all) do
    FRAMEWORKS.each do |framework|
      RubyRaider::Raider
        .new.invoke(:new, nil, %W[capybara_#{framework} -p framework:#{framework} automation:capybara])
    end
  end

  after(:all) do
    FRAMEWORKS.each do |framework|
      FileUtils.rm_rf("capybara_#{framework}")
    end
  end

  shared_examples 'runs tests successfully' do |framework|
    it 'installs dependencies and runs tests without errors' do
      result = run_tests_with(framework)
      expect(result[:success]).to be(true),
                                  "Tests failed for capybara_#{framework}.\n" \
                                  "STDOUT: #{result[:stdout]}\n" \
                                  "STDERR: #{result[:stderr]}"
    end
  end

  context 'with rspec' do
    include_examples 'runs tests successfully', 'rspec'
  end

  context 'with cucumber' do
    include_examples 'runs tests successfully', 'cucumber'
  end

  context 'with minitest' do
    include_examples 'runs tests successfully', 'minitest'
  end

  private

  def run_tests_with(framework)
    project = "capybara_#{framework}"
    test_command = case framework
                   when 'cucumber' then 'bundle exec cucumber features --format pretty'
                   when 'minitest' then 'bundle exec ruby -Itest test/test_login_page.rb'
                   else 'bundle exec rspec spec --format documentation'
                   end

    Bundler.with_unbundled_env do
      Dir.chdir(project) do
        stdout, stderr, status = Open3.capture3('bundle install --quiet')
        return { success: false, stdout:, stderr: } unless status.success?

        stdout, stderr, status = Open3.capture3({ 'HEADLESS' => 'true' }, test_command)
        { success: status.success?, stdout:, stderr: }
      end
    end
  end
end
