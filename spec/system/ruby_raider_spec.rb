require 'fileutils'
require_relative '../spec_helper'
require_relative '../../lib/ruby_raider'

describe RubyRaider do
  shared_examples 'execute web frameworks' do |name|
    it 'runs the tests' do
      Dir.chdir(name) do
        `bundle exec raider u raid`
      end
    end
  end

  context 'with a Rspec and Selenium project' do
    include_examples 'execute web frameworks', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with a Rspec and Watir project' do
    include_examples 'execute web frameworks', "#{FRAMEWORKS.last}_#{AUTOMATION_TYPES[3]}"
  end

  context 'with a Cucumber and Selenium project' do
    include_examples 'execute web frameworks', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[2]}"
  end

  context 'with a Cucumber and Watir project' do
    include_examples 'execute web frameworks', "#{FRAMEWORKS.first}_#{AUTOMATION_TYPES[3]}"
  end
end
