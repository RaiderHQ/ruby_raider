# frozen_string_literal: true

require_relative '../generator'

class MinitestGenerator < Generator
  def generate_login_test
    return unless web? && !visual?

    template('test.tt', "#{name}/test/test_login_page.rb")
  end

  def generate_pdp_test
    return unless mobile?

    template('test.tt', "#{name}/test/test_pdp_page.rb")
  end

  def generate_account_test
    return unless visual?

    template('test.tt', "#{name}/test/test_account_page.rb")
  end
end
