require_relative '../abstract/page'

class Login < Page

  def url(_page)
    'index.php?rt=account/login'
  end

  # Actions

  def login(username, password)
    username_field.set username
    password_field.set password
    login_button.click
  end

  private

  # Elements

  def username_field
    browser.text_field(id: 'loginFrm_loginname')
  end

  def password_field
    browser.text_field(id: 'loginFrm_password')
  end

  def login_button
    browser.button(xpath: "//button[@title='Login']")
  end
end