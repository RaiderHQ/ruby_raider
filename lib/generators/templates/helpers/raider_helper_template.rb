require_relative '../template'

class RaiderHelperTemplate < Template
  def require_spec_helper
    "require_relative 'spec_helper'" if @framework == 'rspec'
  end

  def require_automation_helper
    "require_relative '#{@automation}_helper'" if %w[selenium watir].include?(@automation)
  end

  def require_driver_helper
    "require_relative '#{@automation == 'watir' ? 'browser_helper' : 'driver_helper'}'"
  end

  def body
    <<~EOF
      module Raider
        #{require_spec_helper}
        #{require_automation_helper}
        require_relative 'pom_helper'
        #{require_driver_helper}
        require_relative 'allure_helper'
      end
    EOF
  end
end
