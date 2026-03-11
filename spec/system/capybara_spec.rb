# frozen_string_literal: true

require_relative '../../lib/ruby_raider'
require_relative 'support/system_test_helper'

FRAMEWORKS = %w[cucumber rspec minitest].freeze unless defined?(FRAMEWORKS)

describe 'Capybara based frameworks' do
  include SystemTestHelper

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FRAMEWORKS.each do |framework|
      RubyRaider::Raider
        .new.invoke(:new, nil, %W[capybara_#{framework} -p framework:#{framework} automation:capybara])
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    FRAMEWORKS.each { |framework| FileUtils.rm_rf("capybara_#{framework}") }
  end

  shared_examples 'runs tests successfully' do |framework|
    it 'installs dependencies and runs tests without errors' do
      result = run_tests_with(framework, 'capybara')
      expect(result[:success]).to be(true),
                                  "Tests failed for capybara_#{framework}.\n" \
                                  "STDOUT: #{result[:stdout]}\nSTDERR: #{result[:stderr]}"
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
end
