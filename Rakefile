# frozen_string_literal: true

require_relative 'lib/ruby_raider'

desc 'Create a new test projects'
task :new, [:name] do |_t, args|
  RubyRaider.start
  RubyRaider.new(args.name)
end

desc 'Create a page'
task :page, [:name] do |_t, args|
  RubyRaider.start
  RubyRaider.page(args.page)
end