require_relative '../template'

class BaseSpecTemplate < Template
  def body
    <<~EOF
       require_relative '../helpers/raider'

      class BaseSpec
        include Raider::SpecHelper
      end
    EOF
  end
end
