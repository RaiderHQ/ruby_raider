# frozen_string_literal: true

require_relative '../abstract/page'

class Account < Page
  def url(_page)
    'index.php?rt=account/account'
  end
end
