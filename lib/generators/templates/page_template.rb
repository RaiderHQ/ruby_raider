require_relative 'template'

class PageTemplate < Template
  def body
    element = @automation == 'watir' ? 'browser.element' : 'driver.find_element'
    helper = @automation == 'watir' ? 'Raider::WatirHelper' : 'Raider::SeleniumHelper'

    <<~EOF
      require_relative '../abstract/abstract_page'
      require_relative '../components/header_component'

      class LoginPage < AbstractPage
        using #{helper}

        def url(_page)
          'index.php?rt=account/login'
        end

        # Actions

        def login(username, password)
          username_field.send_keys username
          password_field.send_keys password
          login_button.click_when_present
        end

        # Components

        def header
          HeaderComponent.new(#{element}(class: 'menu_text'))
        end

        private

        # Elements

        def username_field
          #{element}(id: 'loginFrm_loginname')
        end

        def password_field
          #{element}(id: 'loginFrm_password')
        end

        def login_button
          #{element}(xpath: "//button[@title='Login']")
        end
      end
    EOF
  end
end