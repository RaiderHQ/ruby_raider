# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'ruby_raider'
  s.version     = File.read(File.expand_path('lib/version', __dir__)).strip
  s.summary     = 'A gem to make setup and start of UI automation projects easier'
  s.description = 'This gem has everything you need to start working with test automation'
  s.authors     = ['Agustin Pequeno']
  s.email       = 'agustin.pe94@gmail.com'
  s.homepage = 'https://github.com/RubyRaider/ruby_raider'
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1.0'
  s.files  = `git ls-files -z`.split("\x0")
  s.bindir = 'bin'
  s.executables << 'raider'
  s.add_development_dependency 'rake', '~> 13.0.6'
  s.add_development_dependency 'reek', '~> 6.1.0'
  s.add_development_dependency 'rspec', '~> 3.11.0'
  s.add_development_dependency 'rubocop', '~> 1.27'
  s.add_development_dependency 'rubocop-performance', '~> 1.15.0'
  s.add_development_dependency 'rubocop-rspec', '~> 2.9.0'
  s.add_development_dependency 'steep', '~> 1.7.0'

  s.add_runtime_dependency 'thor', '~> 1.2.1'
  s.add_runtime_dependency 'tty-prompt', '~> 0.23.1'
end
