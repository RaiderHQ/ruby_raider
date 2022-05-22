# frozen_string_literal: true

require_relative 'generator'

class RspecGenerator < Generator

  def generate_spec
    template('rspec/spec.tt', "#{name}/spec/login_page_spec.rb")
  end

  def generate_base_spec
    template('rspec/base_spec.tt', "#{name}/spec/base_spec.rb")
  end
end

