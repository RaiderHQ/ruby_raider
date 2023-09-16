# frozen_string_literal: true

require_relative '../generator'

class RspecGenerator < Generator
  def generate_login_spec
    return unless web?

    template('spec.tt', "#{name}/spec/login_page_spec.rb")
  end

  def generate_pdp_spec
    return unless mobile?

    template('spec.tt', "#{name}/spec/pdp_page_spec.rb")
  end
end
