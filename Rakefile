# frozen_string_literal: true

require_relative 'lib/ruby_raider.thor'

desc 'Create a new test projects'
task :new do
  RubyRaider.new(%w[hello]).invoke(:new)
end

desc 'Create a page'
task :page, [:name] do |_t, args|
  RubyRaider.start
  RubyRaider.page(args.page)
end
