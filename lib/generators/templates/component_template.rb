require_relative 'template'

class ComponentTemplate < Template
  def body
    <<~EOF
          require_relative '../abstract/abstract_component'

          class HeaderComponent < AbstractComponent

            def customer_name
              @component.text
            end
          end
    EOF
  end
end
