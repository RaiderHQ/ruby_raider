require_relative '../abstract/abstract_page'
require_relative '../components/header_component'

class AccountPage < AbstractPage

  def url(_page)
    'index.php?rt=account/account'
  end

  # Components

  def header
    HeaderComponent.new(browser.element(class: 'menu_text'))
  end
end