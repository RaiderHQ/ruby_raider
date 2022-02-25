Gem::Specification.new do |s|
  s.name        = 'ruby_raider'
  s.version     = '0.1.0'
  s.summary     = 'A gem to make setup and start of UI automation projects easier'
  s.description = 'This gem contents everything you need to start doing web automation in one simple package'
  s.authors     = ['Agustin Pequeno']
  s.email       = 'agustin.pe94@gmail.com'
  s.homepage = 'http://github.com/aguspe/ruby_raider'
  s.files = ['lib/ruby_raider.rb']
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.0.0'

  s.add_development_dependency 'rspec'

  s.add_runtime_dependency 'highline'
end
