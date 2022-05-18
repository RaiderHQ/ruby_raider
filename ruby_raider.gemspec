# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'ruby_raider'
  s.version     = '0.2.3'
  s.summary     = 'A gem to make setup and start of UI automation projects easier'
  s.description = 'This gem contents everything you need to start doing web automation in one simple package'
  s.authors     = ['Agustin Pequeno']
  s.email       = 'agustin.pe94@gmail.com'
  s.homepage = 'http://github.com/aguspe/ruby_raider'
  s.files = %w[bin/* lib/* lib/**/*]
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.0.0'
  s.files  = `git ls-files -z`.split("\x0")
  s.bindir = 'bin'
  s.executables << 'raider'
  s.add_development_dependency 'rake', '~> 13.0.6'
  s.add_development_dependency 'reek', '~> 6.1.0'
  s.add_development_dependency 'rubocop', '~> 1.27'
  s.add_development_dependency 'rubocop-rspec', '~> 2.9.0'
  s.add_development_dependency 'rspec', '~> 3.11.0'

  s.add_runtime_dependency 'highline', '~> 2.0.3'
  s.add_runtime_dependency 'thor', '~> 1.2.1'
end
