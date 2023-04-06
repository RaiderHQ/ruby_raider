require 'glimmer-dsl-libui'

class BaseComponent
  include Glimmer

  def initialize
    super
    if File.directory?('spec')
      @folder = 'spec'
      @framework = 'rspec'
      @extension = '*_spec.rb'
    else
      @folder = 'features'
      @framework = 'cucumber'
      @extension = '*.features'
    end
  end
end
