# frozen_string_literal: true

require_relative '../generator'

class RspecExamplesGenerator < Generator
  def generate_login_spec
    return if mobile_platform?

    template('spec.tt', "#{name}/spec/login_page_spec.rb")
  end

  def generate_pdp_spec
    return unless mobile_platform?

    template('spec.tt', "#{name}/spec/pdp_page_spec.rb")
  end
end
