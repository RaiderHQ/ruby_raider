# frozen_string_literal: true

require_relative 'lib/ruby_raider'
require_relative 'lib/commands/scaffolding_commands'
require_relative 'lib/desktop/installation_screen'
require_relative 'lib/desktop/runner_screen'

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

desc 'Updates a path'
task :path, [:path] do |_t, args|
  ScaffoldingCommands.new.invoke(:path, nil, %W[#{args.path} -s])
end

desc 'Download mobile builds'
task :builds, [:type] do |_t, args|
  ScaffoldingCommands.new.invoke(:download_builds, nil, %W[#{args.type}])
end

desc 'Open the desktop app'
task :open do
  InstallationScreen.new.launch
end

desc 'Open the run screen'
task :runner do
  RunnerScreen.new.launch
end
