# frozen_string_literal: true

require_relative 'lib/ruby_raider'
require_relative 'lib/commands/scaffolding_commands'
require_relative 'lib/utilities/logger'

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

desc 'Logs a warning'
task :log, [:message] do |_t, args|
  RubyRaider::Logger.warn(args.message)
end

desc 'Runs integration tests'
task :integration, [:type, :name] do |_t, args|
  path = args.type ? "spec/integration/#{args.type}" : 'spec/integration'
  full_path = if args.type == 'generators' && args.name
                "#{path}/#{args.name.downcase}_generator_spec.rb"
              elsif args.type == 'commands' && args.name
                "#{path}/#{args.name.downcase}_commands_spec.rb"
              else
                path
              end

  system "rspec #{full_path}"
end

desc 'Runs system tests'
task :system do |_t|
  system 'rspec spec/system'
end

desc 'Create framework with parameters'
task :new, [:name, :params] do |_t, args|
  system "bin/raider -n #{args.name} -p #{args.params}"
end
