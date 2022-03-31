require_relative '../template'

class WatirHelperTemplate < Template
  def body
    <<~EOF
      require 'watir'

      module Raider
        module WatirHelper
          refine Watir::Element do
            def click_when_present
              wait_until_present
              self.click
            end

            def wait_until_present
              self.wait_until(&:present?)
            end
          end
        end
      end
    EOF
  end
end
