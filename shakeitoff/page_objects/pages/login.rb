# frozen_string_literal: true

require_relative '../abstract/page'

class Login < Page
  def url(_page)
    'index.php?rt=account/login'
  end

  # Actions

  def login(username, password)
    username_field.send_keys username
    password_field.send_keys password
    login_button.click
  end

  private

  # Elements

  def username_field
    driver.find_element(id: 'loginFrm_loginname')
  end

  def password_field
    driver.find_element(id: 'loginFrm_password')
  end

  def login_button
    driver.find_element(xpath: "//button[@title='Login']")
  end
end
