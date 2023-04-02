# frozen_string_literal: true

require_relative '../generator'

class RspecGenerator < Generator
  def generate_base_spec
    template('base_spec.tt', "#{name}/spec/base_spec.rb")
  end
end
