Gem::Specification.new do |s|
  s.name        = 'ruby_raider'
  s.version     = '0.1.1'
  s.summary     = 'A gem to make setup and start of UI automation projects easier'
  s.description = 'This gem contents everything you need to start doing web automation in one simple package'
  s.authors     = ['Agustin Pequeno']
  s.email       = 'agustin.pe94@gmail.com'
  s.files       = ['lib/ruby_raider.rb']
  s.homepage    =
    'https://rubygems.org/gems/ruby_raider'
  s.license = 'MIT'

  s.add_development_dependency 'rspec'

  s.add_runtime_dependency 'highline'
  s.add_runtime_dependency 'thor'
end