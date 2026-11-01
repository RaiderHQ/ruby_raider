# frozen_string_literal: true

require_relative '../generator'

class RspecGenerator < Generator
  # A skeleton has an empty spec/ (the generated CI runs `rspec spec`), and no example specs
  def generate_empty_spec_folder
    return if examples?

    create_file("#{name}/spec/.keep", '')
  end

  def generate_login_spec
    return unless web? && examples?

    template('spec.tt', "#{name}/spec/login_page_spec.rb")
  end

  def generate_pdp_spec
    return unless mobile? && examples?

    template('spec.tt', "#{name}/spec/pdp_page_spec.rb")
  end

  def generate_accessibility_spec
    return unless axe_addon? && web? && examples?

    template('accessibility_spec.tt', "#{name}/spec/accessibility_spec.rb")
  end
end
