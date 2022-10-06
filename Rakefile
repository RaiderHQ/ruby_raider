# frozen_string_literal: true

require_relative 'lib/ruby_raider'
require_relative 'lib/commands/scaffolding_commands'

desc 'Creates a new test project'
task :new, [:name] do |_t, args|
  system "bin/raider -n #{args.name}"
end

desc 'Creates a page'
task :page, [:name, :path] do |_t, args|
  ScaffoldingCommands.new.invoke(:page, nil, %W[:#{args.name} --path #{args.path}])
end

desc 'Sets a browser'
task :browser, [:type, :options] do |_t, args|
  ScaffoldingCommands.new.invoke(:browser, nil, %W[:#{args.type} --opts #{args.options}])
end