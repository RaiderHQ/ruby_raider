# frozen_string_literal: true

require_relative '../template'

# Template for the abstract spec class
class BaseSpecTemplate < Template
  def body
    <<~RUBY
       require_relative '../helpers/raider'

      class BaseSpec
        include Raider::SpecHelper
      end
    RUBY
  end
end
