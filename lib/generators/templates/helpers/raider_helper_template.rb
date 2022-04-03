require_relative '../template'

class RaiderHelperTemplate < Template
  def body
    <<~EOF
      module Raider
        #{"require_relative 'spec_helper'" if @framework == 'rspec'}
        require_relative '#{@automation}_helper'
        require_relative 'pom_helper'
        require_relative '#{@automation == 'watir' ? 'browser_helper' : 'driver_helper'}'
        require_relative 'allure_helper'
      end
    EOF
  end
end
