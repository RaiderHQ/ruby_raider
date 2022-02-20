require 'thor'

class RubyRaider::MenuGenerator < Thor
  include Thor::Actions

  desc 'Choose a valid test framework'
  option :test_framework, :default => :watir

  def install_framework
    case option
    when 'watir'
      pp 'you are installing watir'
    when 'selenium'
      pp 'you are installing selenium'
    end
  end
end
